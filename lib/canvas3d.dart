import 'dart:async';
import 'dart:math';
import 'package:vector_math/vector_math.dart' as VM;
import 'package:flutter/material.dart';

class Face {
  List<VM.Vector3> vertices;
  Face({required this.vertices});
}

class Model {
  final List<VM.Vector3> vertices;
  final List<List<int>> faces;
  const Model({required this.vertices, required this.faces});
}

class BuildingPainter extends CustomPainter {
  final Model model;
  final double rx, ry, rz;

  BuildingPainter(this.model, this.rx, this.ry, this.rz);

  VM.Vector3 transform(VM.Vector3 v) {
    final c = VM.Vector3.copy(v);

    final m = VM.Matrix4.rotationX(rx);
    m.transform3(c);

    final m2 = VM.Matrix4.rotationY(ry);
    m2.transform3(c);

    final m3 = VM.Matrix4.rotationZ(rz);
    m3.transform3(c);

    final m4 = VM.Matrix4.translation(VM.Vector3(0, 0, 10));
    m4.transform3(c);

    return c;
  }

  VM.Vector3 project(VM.Vector3 v) {
    var c = VM.Vector3.copy(v);
    final m = VM.makePerspectiveMatrix(0.58, 0.98, 0.1, 20);
    c = m.perspectiveTransform(c);
    return VM.Vector3(c.x * 280, c.y * 280, c.z * 280);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final transformedVertices = <VM.Vector3>[];
    final projectedVertices = <VM.Vector3>[];

    var faceStroke = Paint();
    faceStroke.color = const Color.fromARGB(255, 0, 0, 0);
    faceStroke.style = PaintingStyle.stroke;
    faceStroke.strokeWidth = 1;

    var faceFill = Paint();
    faceFill.color = const Color.fromARGB(255, 0x20, 0x80, 0xE0);
    faceFill.style = PaintingStyle.fill;

    for (final vert in model.vertices) {
      final tv = transform(vert);
      transformedVertices.add(tv);
      final pv = project(tv);
      projectedVertices.add(pv);
    }

    final cx = size.width / 2.0;
    final cy = size.height / 2.0;

    for (final face in model.faces) {
      // Calculate normal of face
      final v1 = transformedVertices[face[0]];
      final v2 = transformedVertices[face[1]];
      final v3 = transformedVertices[face[2]];
      final a = v2 - v1;
      final b = v3 - v1;
      final cross = a.cross(b);
      final normal = cross / cross.length;

      // Check if face is pointing towards us
      final fv1 = projectedVertices[face[0]];
      final fv2 = projectedVertices[face[1]];
      final fv3 = projectedVertices[face[2]];
      final pv1 = VM.Vector3(fv1.x, fv1.y, 0);
      final pv2 = VM.Vector3(fv2.x, fv2.y, 0);
      final pv3 = VM.Vector3(fv3.x, fv3.y, 0);
      final aa = pv2 - pv1;
      final bb = pv3 - pv1;
      final pcross = aa.cross(bb);

      if (pcross.z > 0) {
        final path = Path();
        final vert = projectedVertices[face[0]];
        path.moveTo(vert.x + cx, vert.y + cy);

        for (final idx in face.skip(1)) {
          final vert = projectedVertices[idx];
          path.lineTo(vert.x + cx, vert.y + cy);
        }

        path.close();

        final light = (50 * normal.z).toInt();
        faceFill.color =
            Color.fromARGB(255, 0x22 + light, 0x33 + light, 0x44 + light);
        canvas.drawPath(path, faceFill);
        canvas.drawPath(path, faceStroke);
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}

class Canvas3D extends StatefulWidget {
  const Canvas3D({Key? key}) : super(key: key);

  @override
  State<Canvas3D> createState() => _Canvas3DState();
}

class _Canvas3DState extends State<Canvas3D> {
  late Model model;

  var rx = 0.0;
  var ry = 0.0;
  var rz = 0.0;
  late Timer timer;

  @override
  void initState() {
    super.initState();

    var vertices = <VM.Vector3>[
      VM.Vector3(-1, 1, -1),
      VM.Vector3(1, 1, -1),
      VM.Vector3(1, -1, -1),
      VM.Vector3(-1, -1, -1),
      VM.Vector3(-1, 1, 1),
      VM.Vector3(1, 1, 1),
      VM.Vector3(1, -1, 1),
      VM.Vector3(-1, -1, 1),
    ];

    var faces = [
      [4, 5, 6, 7],
      [5, 1, 2, 6],
      [1, 0, 3, 2],
      [0, 4, 7, 3],
      [0, 1, 5, 4],
      [7, 6, 2, 3]
    ];

    model = Model(vertices: vertices, faces: faces);

    timer = Timer.periodic(const Duration(milliseconds: 17), (_) {
      setState(() {
        rx += 0.023;
        ry += 0.01;
        rz += 0.0132;
      });
    });
  }

  @override
  void dispose() {
    super.dispose();
    timer.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: BuildingPainter(model, rx, ry, rz),
      child: Container(),
    );
  }
}
