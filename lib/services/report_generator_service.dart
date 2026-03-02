import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:excel/excel.dart' as ex;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class ReportGeneratorService {
  
  // 1. EXCEL HISOBOT GENERATORI
  static Future<void> generateExcel(List<Map<String, dynamic>> data, String title, List<String> columns) async {
    try {
      final excel = ex.Excel.createExcel();
      final sheet = excel['Sheet1'];
      
      sheet.appendRow(columns.map((c) => ex.TextCellValue(c)).toList());
      
      for (var row in data) {
        List<ex.CellValue> rowValues = [];
        for (var col in columns) {
          final val = row[col]?.toString() ?? '';
          rowValues.add(ex.TextCellValue(val));
        }
        sheet.appendRow(rowValues);
      }

      final dir = await getTemporaryDirectory();
      final path = "${dir.path}/${title}_${DateTime.now().millisecondsSinceEpoch}.xlsx";
      final file = File(path);
      await file.writeAsBytes(excel.encode()!);
      await Share.shareXFiles([XFile(path)], text: "Aristokrat Mebel - ${title} (Excel)");
    } catch (e) {
      debugPrint("Excel generatsiyada xato: $e");
    }
  }

  // 2. PDF HISOBOT GENERATORI
  static Future<void> generatePdf(List<Map<String, dynamic>> data, String title, List<String> columns) async {
    try {
      final pdf = pw.Document();
      
      List<List<String>> tableData = [columns];
      for (var row in data) {
        tableData.add(columns.map((c) => row[c]?.toString() ?? '').toList());
      }

      pdf.addPage(pw.MultiPage(
        build: (context) => [
          pw.Header(level: 0, child: pw.Text("Aristokrat Mebel - ${title}", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold))),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(context: context, data: tableData),
        ],
      ));

      final dir = await getTemporaryDirectory();
      final path = "${dir.path}/${title}_${DateTime.now().millisecondsSinceEpoch}.pdf";
      final file = File(path);
      await file.writeAsBytes(await pdf.save());
      await Share.shareXFiles([XFile(path)], text: "Aristokrat Mebel - ${title} (PDF)");
    } catch (e) {
      debugPrint("PDF generatsiyada xato: $e");
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
        text: TextSpan(
          text: "ARISTOKRAT MEBEL\n${title}", 
          style: const TextStyle(color: Color(0xFF2E5BFF), fontSize: 40, fontWeight: FontWeight.bold)
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );
      titlePainter.layout(maxWidth: 800);
      titlePainter.paint(canvas, const Offset(0, 50));

      double currentY = 200;
      final borderPaint = Paint()..color = const Color(0xFFEEEEEE)..style = PaintingStyle.fill;
      
      summaryStats.forEach((key, value) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(50, currentY, 700, 100), const Radius.circular(15)), 
          borderPaint
        );
        
        final keyPainter = TextPainter(
          text: TextSpan(text: key, style: const TextStyle(color: Colors.black54, fontSize: 24)), 
          textDirection: TextDirection.ltr
        );
        keyPainter.layout();
        keyPainter.paint(canvas, Offset(80, currentY + 35));

        final valPainter = TextPainter(
          text: TextSpan(text: value, style: const TextStyle(color: Colors.black, fontSize: 32, fontWeight: FontWeight.bold)), 
          textDirection: TextDirection.ltr
        );
        valPainter.layout();
        valPainter.paint(canvas, Offset(750 - valPainter.width, currentY + 30));

        currentY += 130;
      });

      final picture = recorder.endRecording();
      final img = await picture.toImage(800, currentY.toInt() + 50);
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      final buffer = byteData!.buffer.asUint8List();

      final dir = await getTemporaryDirectory();
      final path = "${dir.path}/infografika_${DateTime.now().millisecondsSinceEpoch}.png";
      final file = File(path);
      await file.writeAsBytes(buffer);
      await Share.shareXFiles([XFile(path)], text: "Aristokrat Mebel Infografika - ${title}");
    } catch (e) {
      debugPrint("Infografika xatosi: $e");
    }
  }
}
