import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

/// PNG sin metadatos, comprimido con zlib de Dart: sin herramientas externas.
/// RGB para el gráfico de Play y las capturas de las tiendas; RGBA para el
/// icono de Play.
///
/// Con [alpha] en false el PNG sale **sin canal alfa** (color type 2), que es
/// lo que piden App Store y Google Play, y falla si algún píxel no es opaco.
Future<Uint8List> encodePng(
  ui.Image image, {
  bool alpha = false,
  String name = 'imagen',
}) async {
  final data = await image.toByteData(
    format: ui.ImageByteFormat.rawStraightRgba,
  );
  final rgba = data!.buffer.asUint8List();
  final channels = alpha ? 4 : 3;
  final stride = image.width * channels;
  final rows = Uint8List((stride + 1) * image.height);
  for (var y = 0; y < image.height; y++) {
    final start = y * (stride + 1);
    rows[start] = 1; // Filtro Sub: comprime bien el texto y los fondos planos.
    for (var x = 0; x < image.width; x++) {
      final pixel = (y * image.width + x) * 4;
      if (!alpha && rgba[pixel + 3] != 255) {
        throw StateError('El PNG RGB debe ser opaco: $name');
      }
      for (var c = 0; c < channels; c++) {
        final left = x == 0 ? 0 : rgba[pixel - 4 + c];
        rows[start + 1 + x * channels + c] = (rgba[pixel + c] - left) & 255;
      }
    }
  }
  final header = ByteData(13)
    ..setUint32(0, image.width)
    ..setUint32(4, image.height)
    ..setUint8(8, 8)
    ..setUint8(9, alpha ? 6 : 2);
  final png = BytesBuilder()
    ..add([137, 80, 78, 71, 13, 10, 26, 10])
    ..add(_chunk('IHDR', header.buffer.asUint8List()))
    ..add(_chunk('IDAT', ZLibEncoder(level: 9).convert(rows)))
    ..add(_chunk('IEND', []));
  return png.takeBytes();
}

/// Escribe el PNG de [image] en `docs/readme/`.
Future<void> writeReadmePng(
  ui.Image image,
  String name, {
  bool alpha = false,
}) async {
  final png = await encodePng(image, alpha: alpha, name: name);
  final out = File('../docs/readme/$name');
  out.parent.createSync(recursive: true);
  out.writeAsBytesSync(png);
}

List<int> _chunk(String type, List<int> data) {
  final payload = [...type.codeUnits, ...data];
  var crc = 0xffffffff;
  for (final byte in payload) {
    crc ^= byte;
    for (var bit = 0; bit < 8; bit++) {
      crc = (crc >> 1) ^ ((crc & 1) == 1 ? 0xedb88320 : 0);
    }
  }
  final length = ByteData(4)..setUint32(0, data.length);
  final checksum = ByteData(4)..setUint32(0, crc ^ 0xffffffff);
  return [
    ...length.buffer.asUint8List(),
    ...payload,
    ...checksum.buffer.asUint8List(),
  ];
}
