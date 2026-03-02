  // 3. BONUS: RASMLI INFOGRAFIKA GENERATORI
  static Future<void> generateImageInfographic(Map<String, String> summaryStats, String title) async {
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 800, 1000));
      
      final bgPaint = Paint()..color = const Color(0xFFFFFFFF);
      canvas.drawRect(const Rect.fromLTWH(0, 0, 800, 1000), bgPaint);

      final titlePainter = TextPainter(
        text: TextSpan(text: "ARISTOKRAT MEBEL\n$title", style: const TextStyle(color: Color(0xFF2E5BFF), fontSize: 40, fontWeight: FontWeight.bold)),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );
      titlePainter.layout(maxWidth: 800);
      titlePainter.paint(canvas, const Offset(0, 50));

      double currentY = 200;
      final borderPaint = Paint()..color = const Color(0xFFEEEEEE)..style = PaintingStyle.fill;
      
      summaryStats.forEach((key, value) {
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(50, currentY, 700, 100), const Radius.circular(15)), borderPaint);
        
        final keyPainter = TextPainter(text: TextSpan(text: key, style: const TextStyle(color: Colors.black54, fontSize: 24)), textDirection: TextDirection.ltr);
        keyPainter.layout();
        keyPainter.paint(canvas, Offset(80, currentY + 35));

        final valPainter = TextPainter(text: TextSpan(text: value, style: const TextStyle(color: Colors.black, fontSize: 32, fontWeight: FontWeight.bold)), textDirection: TextDirection.ltr);
        valPainter.layout();
        valPainter.paint(canvas, Offset(750 - valPainter.width, currentY + 30));

        currentY += 130;
      });

      final picture = recorder.endRecording();
      final img = await picture.toImage(800, currentY.toInt() + 50);
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      final buffer = byteData!.buffer.asUint8List();

      final dir = await getTemporaryDirectory();
      // XATOLIK TUZATILDI
      final path = "${dir.path}/infografika_${DateTime.now().millisecondsSinceEpoch}.png";
      final file = File(path);
      await file.writeAsBytes(buffer);
      await Share.shareXFiles([XFile(path)], text: "Aristokrat Mebel Infografika - $title");
    } catch (e) {
      debugPrint("Infografika xatosi: $e");
    }
  }
}
  // 3. BONUS: RASMLI INFOGRAFIKA GENERATORI
  static Future<void> generateImageInfographic(Map<String, String> summaryStats, String title) async {
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 800, 1000));
      
      final bgPaint = Paint()..color = const Color(0xFFFFFFFF);
      canvas.drawRect(const Rect.fromLTWH(0, 0, 800, 1000), bgPaint);

      final titlePainter = TextPainter(
        text: TextSpan(text: "ARISTOKRAT MEBEL\n$title", style: const TextStyle(color: Color(0xFF2E5BFF), fontSize: 40, fontWeight: FontWeight.bold)),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );
      titlePainter.layout(maxWidth: 800);
      titlePainter.paint(canvas, const Offset(0, 50));

      double currentY = 200;
      final borderPaint = Paint()..color = const Color(0xFFEEEEEE)..style = PaintingStyle.fill;
      
      summaryStats.forEach((key, value) {
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(50, currentY, 700, 100), const Radius.circular(15)), borderPaint);
        
        final keyPainter = TextPainter(text: TextSpan(text: key, style: const TextStyle(color: Colors.black54, fontSize: 24)), textDirection: TextDirection.ltr);
        keyPainter.layout();
        keyPainter.paint(canvas, Offset(80, currentY + 35));

        final valPainter = TextPainter(text: TextSpan(text: value, style: const TextStyle(color: Colors.black, fontSize: 32, fontWeight: FontWeight.bold)), textDirection: TextDirection.ltr);
        valPainter.layout();
        valPainter.paint(canvas, Offset(750 - valPainter.width, currentY + 30));

        currentY += 130;
      });

      final picture = recorder.endRecording();
      final img = await picture.toImage(800, currentY.toInt() + 50);
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      final buffer = byteData!.buffer.asUint8List();

      final dir = await getTemporaryDirectory();
      // XATOLIK TUZATILDI
      final path = "${dir.path}/infografika_${DateTime.now().millisecondsSinceEpoch}.png";
      final file = File(path);
      await file.writeAsBytes(buffer);
      await Share.shareXFiles([XFile(path)], text: "Aristokrat Mebel Infografika - $title");
    } catch (e) {
      debugPrint("Infografika xatosi: $e");
    }
  }
}
