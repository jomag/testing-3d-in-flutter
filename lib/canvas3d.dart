import 'dart:async';
import 'package:vector_math/vector_math_64.dart';
import 'package:flutter/material.dart';
import 'package:collection/collection.dart';

abstract class RenderObject {
  final double z;
  RenderObject(this.z);
  void render(Canvas canvas);
}

class FaceRenderObject extends RenderObject {
  final Color color;
  final List<Vector3> verts;
  final List<Vector2> projectedVerts;
  late Vector3 normal;

  FaceRenderObject(this.verts, this.projectedVerts, this.color)
      : super(
          verts.map((v) => v.z).sum / verts.length,
        ) {
    final a = verts[1] - verts[0];
    final b = verts[2] - verts[0];
    final cross = a.cross(b);
    normal = cross / cross.length;
  }

  bool pointingAway() {
    final v1 = projectedVerts[0];
    final v2 = projectedVerts[1];
    final v3 = projectedVerts[2];
    final pv1 = Vector3(v1.x, v1.y, 0);
    final pv2 = Vector3(v2.x, v2.y, 0);
    final pv3 = Vector3(v3.x, v3.y, 0);
    final cross = (pv2 - pv1).cross(pv3 - pv1);
    return cross.z < 0;
  }

  @override
  void render(Canvas canvas) {
    var faceStroke = Paint();
    faceStroke.color = const Color.fromARGB(255, 0, 0, 0);
    faceStroke.style = PaintingStyle.stroke;
    faceStroke.strokeWidth = 1;

    var faceFill = Paint();
    faceFill.color = const Color.fromARGB(255, 0x20, 0x80, 0xE0);
    faceFill.style = PaintingStyle.fill;

    final path = Path();
    final vert = projectedVerts[0];
    path.moveTo(vert.x, vert.y);

    for (final vert in projectedVerts.skip(1)) {
      path.lineTo(vert.x, vert.y);
    }

    path.close();

    final light = (50 * normal.z).toInt();
    faceFill.color =
        Color.fromARGB(255, 0x22 + light, 0x33 + light, 0x44 + light);
    canvas.drawPath(path, faceFill);
    canvas.drawPath(path, faceStroke);
  }
}

class BobRenderObject extends RenderObject {
  final Vector3 pos;
  final Vector2 screenPos;
  BobRenderObject(this.pos, this.screenPos) : super(pos.z);

  @override
  void render(Canvas canvas) {
    var fill = Paint()
      ..color = const Color.fromARGB(255, 200, 30, 20)
      ..style = PaintingStyle.fill;
    var hilight = Paint()
      ..color = const Color.fromARGB(255, 230, 150, 140)
      ..style = PaintingStyle.fill;
    var shadow = Paint()
      ..color = const Color.fromARGB(255, 100, 15, 10)
      ..style = PaintingStyle.fill;

    final x = screenPos.x;
    final y = screenPos.y;
    canvas.drawCircle(Offset(x, y), 20, shadow);
    canvas.drawCircle(Offset(x - 1, y - 1), 16, fill);
    canvas.drawCircle(Offset(x - 7, y - 7), 5, hilight);
  }
}

class Face {
  List<Vector3> vertices;
  Face({required this.vertices});
}

class Bob {
  final Vector3 pos;
  const Bob(this.pos);
}

class Model {
  final List<Vector3> vertices;
  final List<List<int>> faces;
  final List<Bob> bobs;
  const Model(
      {required this.vertices, required this.faces, required this.bobs});
}

class BuildingPainter extends CustomPainter {
  List<Matrix4> transformationMatrixStack;
  Matrix4 projectionMatrix;

  final List<RenderObject> renderObjects = [];
  late double centerX, centerY;

  final List<Model> models;
  final double rx, ry, rz;

  BuildingPainter(this.models, this.rx, this.ry, this.rz)
      : transformationMatrixStack = [Matrix4.identity()],
        projectionMatrix = makePerspectiveMatrix(0.58, 0.98, 0.1, 20);

  Vector2 project(Vector3 v) {
    var c = Vector3.copy(v);
    c = projectionMatrix.perspectiveTransform(c);
    return Vector2(c.x * 280 + centerX, c.y * 280 + centerY);
  }

  void renderModelBobs(Model model) {
    final tm = transformationMatrixStack.last;

    for (var bob in model.bobs) {
      final transformed = tm.transform3(Vector3.copy(bob.pos));
      final projected = project(transformed);
      renderObjects.add(BobRenderObject(transformed, projected));
    }
  }

  void renderModel(Model model) {
    const color = Color.fromARGB(0xFF, 0x20, 0x80, 0xE0);

    final tm = transformationMatrixStack.last;

    final transformed = model.vertices
        .map((vert) => tm.transform3(Vector3.copy(vert)))
        .toList();

    final projected = transformed.map((vert) => project(vert)).toList();

    var cnt = 0;
    for (var faceVertices in model.faces) {
      final verts = faceVertices.map((n) => transformed[n]).toList();
      final projVerts = faceVertices.map((n) => projected[n]).toList();
      final obj = FaceRenderObject(verts, projVerts, color);
      if (!obj.pointingAway()) {
        renderObjects.add(obj);
        cnt += 1;
      }
    }

    renderModelBobs(model);
  }

  void flush(
    Canvas canvas,
  ) {
    renderObjects.sort((a, b) => a.z < b.z ? 1 : (a.z > b.z ? -1 : 0));
    for (var obj in renderObjects) {
      obj.render(canvas);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    centerX = size.width / 2.0;
    centerY = size.height / 2.0;

    final m0 = Matrix4.identity()
      ..translate(0.0, 0.0, 10.0)
      ..rotateX(rx)
      ..rotateY(ry)
      ..rotateZ(rz);
    transformationMatrixStack = [m0];

    renderModel(models[1]);

    final m1 = Matrix4.identity()
      ..translate(0.0, 0.0, 10.0)
      ..rotateX(-rx)
      ..rotateY(ry * 0.3)
      ..rotateZ(rz * 0.8);
    // transformationMatrixStack = [m1];

    // renderModel(models[1]);

    flush(canvas);
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
  late Model cube, bobs;

  var rx = 0.0;
  var ry = 0.0;
  var rz = 0.0;
  late Timer timer;

  List<Bob> createBobs(double step) {
    final bobs = <Bob>[];

    for (var x = -1.0; x <= 1.0; x += step) {
      for (var y = -1.0; y <= 1.0; y += step) {
        for (var z = -1.0; z <= 1.0; z += step) {
          bobs.add(Bob(Vector3(x, y, z)));
        }
      }
    }

    return bobs;
  }

  @override
  void initState() {
    super.initState();

    var vertices = <Vector3>[
      Vector3(-0.9, 0.9, -0.9),
      Vector3(0.9, 0.9, -0.9),
      Vector3(0.9, -0.9, -0.9),
      Vector3(-0.9, -0.9, -0.9),
      Vector3(-0.9, 0.9, 0.9),
      Vector3(0.9, 0.9, 0.9),
      Vector3(0.9, -0.9, 0.9),
      Vector3(-0.9, -0.9, 0.9),
    ];

    var faces = [
      [4, 5, 6, 7],
      [5, 1, 2, 6],
      [1, 0, 3, 2],
      [0, 4, 7, 3],
      [0, 1, 5, 4],
      [7, 6, 2, 3]
    ];

    cube = Model(vertices: vertices, faces: faces, bobs: []);
    bobs = Model(vertices: [], faces: [], bobs: createBobs(2.0 / 2.0));

    timer = Timer(const Duration(milliseconds: 4000), () {
      bobs = Model(vertices: [], faces: [], bobs: createBobs(2.0 / 4.0));
    });

    timer = Timer(const Duration(milliseconds: 16000), () {
      bobs = Model(vertices: [], faces: [], bobs: createBobs(2.0 / 8.0));
    });

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
      painter: BuildingPainter([cube, bobs], rx, ry, rz),
      child: Container(),
    );
  }
}
