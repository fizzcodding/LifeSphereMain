import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

/// Prepares prescription photos for OCR by producing the clearest possible
/// grayscale/binary image from the original capture.
///
/// Everything here runs on pure Dart + `dart:ui` so no native image
/// dependencies are added to the project. The pipeline deliberately does
/// NOT apply every operation blindly: it generates a few candidate
/// renderings (mild enhancement, shadow removal, adaptive threshold) and
/// keeps the one with the best text-legibility score.
class PrescriptionImagePipeline {
  PrescriptionImagePipeline._();

  /// Longest edge cap. Prescriptions stay readable while bounding memory.
  static const _maxEdge = 1600;

  /// Runs the preprocessing pipeline and returns PNG-encoded bytes of the
  /// best candidate, plus a human-readable description of what was chosen
  /// (useful for the processing status UI).
  static Future<PrescriptionProcessResult> process(Uint8List bytes) async {
    final image = await _decode(bytes);
    try {
      final plane = await _toGrayscalePlane(image);
      final deskewed = _maybeDeskew(plane);

      final candidates = <_Candidate>[
        _Candidate.from(
          _enhance(deskewed, shadowFree: false, sharpen: true),
          label: 'contrast enhancement',
        ),
        _Candidate.from(
          _enhance(deskewed, shadowFree: true, sharpen: true),
          label: 'shadow-flattened enhancement',
        ),
        _adaptiveThreshold(
          _enhance(deskewed, shadowFree: true, sharpen: false),
        ),
      ];

      _Candidate best = candidates.first;
      var bestScore = -1.0;
      for (final c in candidates) {
        final score = _legibilityScore(c);
        if (score > bestScore) {
          bestScore = score;
          best = c;
        }
      }

      final png = await _encodePng(best);
      return PrescriptionProcessResult(png: png, method: best.label);
    } finally {
      image.dispose();
    }
  }

  // ---------------------------------------------------------------- decode

  static Future<ui.Image> _decode(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes, targetWidth: _maxEdge);
    try {
      final frame = await codec.getNextFrame();
      return frame.image;
    } finally {
      codec.dispose();
    }
  }

  static Future<_Plane> _toGrayscalePlane(ui.Image image) async {
    final data = await image.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
    if (data == null) {
      throw const PrescriptionImageException('Could not read image data.');
    }
    final px = data.buffer.asUint8List();
    final w = image.width, h = image.height;
    final gray = Float32List(w * h);
    for (var i = 0; i < w * h; i++) {
      final o = i * 4;
      gray[i] = 0.299 * px[o] + 0.587 * px[o + 1] + 0.114 * px[o + 2];
    }
    return _Plane(gray, w, h);
  }

  // --------------------------------------------------------------- deskew

  /// Estimates skew from projection-profile variance on a small downscale;
  /// rotates only when a meaningful tilt was found.
  static _Plane _maybeDeskew(_Plane p) {
    final small = _resample(p, 200, math.max(1, (p.height * 200 / p.width).round()));
    const angles = [-6, -5, -4, -3, -2, -1, 0, 1, 2, 3, 4, 5, 6];
    double bestVar = -1;
    var bestAngle = 0.0;
    for (final a in angles) {
      final v = _projectionVariance(small, a * math.pi / 180);
      if (v > bestVar) {
        bestVar = v;
        bestAngle = a.toDouble();
      }
    }
    if (bestAngle.abs() < 1) return p;
    return _rotate(p, -bestAngle);
  }

  static double _projectionVariance(_Plane p, double radians) {
    final rows = Float32List(p.height);
    final sin = math.sin(radians);
    for (var y = 0; y < p.height; y++) {
      var sum = 0.0;
      for (var x = 0; x < p.width; x += 2) {
        final yy = (y + (x - p.width / 2) * sin).round();
        if (yy >= 0 && yy < p.height) sum += 255 - p.gray[yy * p.width + x];
      }
      rows[y] = sum;
    }
    return _variance(rows);
  }

  static _Plane _rotate(_Plane p, double radians) {
    final out = Float32List(p.gray.length);
    final cx = p.width / 2, cy = p.height / 2;
    final cos = math.cos(radians), sin = math.sin(radians);
    for (var y = 0; y < p.height; y++) {
      for (var x = 0; x < p.width; x++) {
        final dx = x - cx, dy = y - cy;
        final sx = cx + dx * cos - dy * sin;
        final sy = cy + dx * sin + dy * cos;
        out[y * p.width + x] = _bilinear(p, sx, sy);
      }
    }
    return _Plane(out, p.width, p.height);
  }

  static double _bilinear(_Plane p, double x, double y) {
    if (x < 0 || y < 0 || x >= p.width - 1 || y >= p.height - 1) return 255;
    final x0 = x.floor(), y0 = y.floor();
    final fx = x - x0, fy = y - y0;
    final v00 = p.gray[y0 * p.width + x0];
    final v10 = p.gray[y0 * p.width + x0 + 1];
    final v01 = p.gray[(y0 + 1) * p.width + x0];
    final v11 = p.gray[(y0 + 1) * p.width + x0 + 1];
    return v00 * (1 - fx) * (1 - fy) +
        v10 * fx * (1 - fy) +
        v01 * (1 - fx) * fy +
        v11 * fx * fy;
  }

  // ----------------------------------------------------- candidate passes

  /// Percentile contrast stretch + optional shadow flattening + unsharp mask.
  static _Plane _enhance(
    _Plane p, {
    required bool shadowFree,
    required bool sharpen,
  }) {
    var g = _percentileStretch(p, 5, 95);
    if (shadowFree) g = _removeShadows(g);
    if (sharpen) g = _unsharp(g, amount: 0.6);
    return g;
  }

  static _Plane _percentileStretch(_Plane p, double loP, double hiP) {
    final hist = List<int>.filled(256, 0);
    for (final v in p.gray) {
      hist[v.clamp(0, 255).round()]++;
    }
    final total = p.gray.length;
    var acc = 0;
    var lo = 0, hi = 255;
    for (var i = 0; i < 256; i++) {
      acc += hist[i];
      if (acc >= total * loP / 100) {
        lo = i;
        break;
      }
    }
    acc = 0;
    for (var i = 255; i >= 0; i--) {
      acc += hist[i];
      if (acc >= total * (100 - hiP) / 100) {
        hi = i;
        break;
      }
    }
    if (hi - lo < 10) return p;
    final scale = 255 / (hi - lo);
    final out = Float32List(p.gray.length);
    for (var i = 0; i < p.gray.length; i++) {
      out[i] = ((p.gray[i] - lo) * scale).clamp(0, 255);
    }
    return _Plane(out, p.width, p.height);
  }

  /// Divides the image by its local mean to flatten uneven lighting/shadows.
  static _Plane _removeShadows(_Plane p) {
    final bg = _boxBlur(p, math.max(8, math.min(p.width, p.height) ~/ 16));
    final out = Float32List(p.gray.length);
    for (var i = 0; i < p.gray.length; i++) {
      final b = math.max(bg[i], 1);
      out[i] = (p.gray[i] / b * 230).clamp(0, 255);
    }
    return _Plane(out, p.width, p.height);
  }

  /// Bradley/Wellner adaptive threshold using an integral image.
  static _Candidate _adaptiveThreshold(_Plane p) {
    final w = p.width, h = p.height;
    final integral = Float64List((w + 1) * (h + 1));
    for (var y = 0; y < h; y++) {
      var rowSum = 0.0;
      for (var x = 0; x < w; x++) {
        rowSum += p.gray[y * w + x];
        integral[(y + 1) * (w + 1) + x + 1] =
            integral[y * (w + 1) + x + 1] + rowSum;
      }
    }
    final r = math.max(4, math.min(w, h) ~/ 16);
    final out = Float32List(p.gray.length);
    var dark = 0;
    for (var y = 0; y < h; y++) {
      final y0 = math.max(0, y - r), y1 = math.min(h - 1, y + r);
      for (var x = 0; x < w; x++) {
        final x0 = math.max(0, x - r), x1 = math.min(w - 1, x + r);
        final count = (x1 - x0 + 1) * (y1 - y0 + 1);
        final sum = integral[(y1 + 1) * (w + 1) + x1 + 1] -
            integral[y0 * (w + 1) + x1 + 1] -
            integral[(y1 + 1) * (w + 1) + x0] +
            integral[y0 * (w + 1) + x0];
        out[y * w + x] = p.gray[y * w + x] < sum / count * 0.85 ? 0 : 255;
        if (out[y * w + x] == 0) dark++;
      }
    }
    return _Candidate(
      gray: out,
      width: w,
      height: h,
      label: 'adaptive threshold',
      inkRatio: dark / p.gray.length,
    );
  }

  static _Plane _unsharp(_Plane p, {required double amount}) {
    final blur = _boxBlur(p, 2);
    final out = Float32List(p.gray.length);
    for (var i = 0; i < p.gray.length; i++) {
      out[i] = (p.gray[i] + amount * (p.gray[i] - blur[i])).clamp(0, 255);
    }
    return _Plane(out, p.width, p.height);
  }

  /// Fast separable box blur using running sums.
  static Float32List _boxBlur(_Plane p, int radius) {
    final w = p.width, h = p.height;
    final tmp = Float32List(p.gray.length);
    for (var y = 0; y < h; y++) {
      var sum = 0.0;
      for (var x = -radius; x <= radius; x++) {
        sum += p.gray[y * w + x.clamp(0, w - 1)];
      }
      for (var x = 0; x < w; x++) {
        tmp[y * w + x] = sum / (2 * radius + 1);
        sum -= p.gray[y * w + (x - radius).clamp(0, w - 1)];
        sum += p.gray[y * w + (x + radius + 1).clamp(0, w - 1)];
      }
    }
    final out = Float32List(p.gray.length);
    for (var x = 0; x < w; x++) {
      var sum = 0.0;
      for (var y = -radius; y <= radius; y++) {
        sum += tmp[y.clamp(0, h - 1) * w + x];
      }
      for (var y = 0; y < h; y++) {
        out[y * w + x] = sum / (2 * radius + 1);
        sum -= tmp[(y - radius).clamp(0, h - 1) * w + x];
        sum += tmp[(y + radius + 1).clamp(0, h - 1) * w + x];
      }
    }
    return out;
  }

  // --------------------------------------------------------------- scoring

  /// Text-legibility score: mean absolute gradient (sharpness of strokes),
  /// with a heavy penalty when the ink coverage is implausible for a
  /// document (e.g. binarization collapsed to all-black or all-white).
  static double _legibilityScore(_Candidate c) {
    final w = c.width, h = c.height;
    var sum = 0.0;
    var samples = 0;
    for (var y = 1; y < h - 1; y += 2) {
      for (var x = 1; x < w - 1; x += 2) {
        final v = c.gray[y * w + x];
        sum += (v - c.gray[y * w + x + 1]).abs() +
            (v - c.gray[(y + 1) * w + x]).abs();
        samples++;
      }
    }
    var score = samples > 0 ? sum / samples : 0.0;

    if (c.inkRatio != null) {
      final ok = c.inkRatio! >= 0.015 && c.inkRatio! <= 0.45;
      if (!ok) score *= 0.1;
    }
    return score;
  }

  // ----------------------------------------------------------------- utils

  static _Plane _resample(_Plane p, int newW, int newH) {
    final out = Float32List(math.max(1, newW * newH));
    for (var y = 0; y < newH; y++) {
      final sy = (y * p.height / newH).floor().clamp(0, p.height - 1);
      for (var x = 0; x < newW; x++) {
        final sx = (x * p.width / newW).floor().clamp(0, p.width - 1);
        out[y * newW + x] = p.gray[sy * p.width + sx];
      }
    }
    return _Plane(out, newW, newH);
  }

  static double _variance(Float32List v) {
    var mean = 0.0;
    for (final x in v) {
      mean += x;
    }
    mean /= v.length;
    var acc = 0.0;
    for (final x in v) {
      acc += (x - mean) * (x - mean);
    }
    return acc / v.length;
  }

  static Future<Uint8List> _encodePng(_Candidate c) async {
    final rgba = Uint8List(c.width * c.height * 4);
    for (var i = 0; i < c.gray.length; i++) {
      final v = c.gray[i].round().clamp(0, 255);
      final o = i * 4;
      rgba[o] = v;
      rgba[o + 1] = v;
      rgba[o + 2] = v;
      rgba[o + 3] = 255;
    }
    final buffer = await ui.ImmutableBuffer.fromUint8List(rgba);
    final descriptor = ui.ImageDescriptor.raw(
      buffer,
      width: c.width,
      height: c.height,
      pixelFormat: ui.PixelFormat.rgba8888,
    );
    final codec = await descriptor.instantiateCodec();
    try {
      final frame = await codec.getNextFrame();
      try {
        final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
        if (data == null) {
          throw const PrescriptionImageException(
            'Could not encode processed image.',
          );
        }
        return data.buffer.asUint8List();
      } finally {
        frame.image.dispose();
      }
    } finally {
      codec.dispose();
      descriptor.dispose();
      buffer.dispose();
    }
  }
}

/// A grayscale pixel buffer with explicit dimensions.
class _Plane {
  final Float32List gray;
  final int width;
  final int height;
  const _Plane(this.gray, this.width, this.height);
}

/// One candidate preprocessing output competing for the best OCR input.
class _Candidate {
  final Float32List gray;
  final int width;
  final int height;
  final String label;

  /// Fraction of dark pixels (only set for binary candidates).
  final double? inkRatio;

  /// Wraps a plain grayscale plane with its pipeline label.
  factory _Candidate.from(_Plane plane, {required String label}) => _Candidate(
        gray: plane.gray,
        width: plane.width,
        height: plane.height,
        label: label,
      );

  const _Candidate({
    required this.gray,
    required this.width,
    required this.height,
    required this.label,
    this.inkRatio,
  });
}

class PrescriptionProcessResult {
  final Uint8List png;
  final String method;

  const PrescriptionProcessResult({required this.png, required this.method});
}

class PrescriptionImageException implements Exception {
  final String message;
  const PrescriptionImageException(this.message);

  @override
  String toString() => message;
}
