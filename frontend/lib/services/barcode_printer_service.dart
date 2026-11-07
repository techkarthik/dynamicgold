import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/barcode_models.dart';

class BarcodePrinterService {
  /// Converts millimeters to PDF points (72 pt per inch, 25.4 mm per inch)
  static double mmToPt(double mm) => mm * (72.0 / 25.4);

  /// Resolves token expressions in a template string with item data
  static String formatElementText({
    required BarcodeElement elem,
    required StockTaggedItem item,
    String defaultCompanyName = 'PROGOLD JEWELLERY',
  }) {
    final currencyFmt = NumberFormat("#,##,##0", "en_IN");
    final decimal3Fmt = NumberFormat("0.000", "en_US");
    final decimal2Fmt = NumberFormat("0.00", "en_US");

    String formatVal(String key) {
      switch (key) {
        case 'sku':
          return item.skuCode.isNotEmpty ? item.skuCode : '27A001';
        case 'gross_weight':
          return decimal3Fmt.format(item.grossWeight);
        case 'net_weight':
          return decimal3Fmt.format(item.netWeight);
        case 'stone_pcs':
          return '${item.stonePcs}';
        case 'stone_weight':
          return decimal3Fmt.format(item.stoneWeight);
        case 'stone_amt':
          return currencyFmt.format(item.stoneAmt);
        case 'stone_info':
          return item.stonePcs > 0
              ? 'S:${item.stonePcs}/${decimal3Fmt.format(item.stoneWeight)}g'
              : '';
        case 'diamond_pcs':
          return '${item.diamondPcs}';
        case 'diamond_weight':
          return decimal3Fmt.format(item.diamondWeight);
        case 'diamond_amt':
          return currencyFmt.format(item.diamondAmt);
        case 'diamond_info':
          return item.diamondPcs > 0
              ? 'D:${item.diamondPcs}/${decimal2Fmt.format(item.diamondWeight)}ct'
              : '';
        case 'purity':
          return item.purityName.isNotEmpty ? item.purityName : '22KT';
        case 'style':
        case 'stylename':
          return item.styleName;
        case 'size':
        case 'sizename':
          return item.sizeName;
        case 'product_name':
          return item.productName.isNotEmpty ? item.productName : 'JEWELLERY';
        case 'subproduct_name':
          return item.subproductName;
        case 'company_name':
          return item.companyName.isNotEmpty ? item.companyName : defaultCompanyName;
        case 'designer_name':
          return item.designerName;
        case 'board_rate':
          return currencyFmt.format(item.boardRate);
        case 'sales_va_percent':
          return decimal2Fmt.format(item.salesVaPercent);
        case 'sales_mc':
          return currencyFmt.format(item.salesMcPerGram);
        case 'sales_total_amt':
          return currencyFmt.format(item.salesTotalAmt);
        case 'lot_number':
          return item.lotNumber;
        case 'huid':
          return item.huid;
        default:
          return '';
      }
    }

    String result = elem.formatTemplate;
    if (result.isEmpty) {
      final directVal = formatVal(elem.fieldKey);
      result = directVal.isNotEmpty ? '${elem.labelPrefix}$directVal' : elem.labelPrefix;
    } else {
      // Replace tokens like {gross_weight}, {sku}, {stone_pcs}, etc.
      final matches = RegExp(r'\{([a-zA-Z0-9_]+)\}').allMatches(result);
      for (final m in matches) {
        final token = m.group(1) ?? '';
        final val = formatVal(token);
        result = result.replaceAll('{$token}', val);
      }
      if (elem.labelPrefix.isNotEmpty && !result.startsWith(elem.labelPrefix)) {
        result = '${elem.labelPrefix}$result';
      }
    }

    return result.trim();
  }

  /// Builds a sample StockTaggedItem for template designer preview
  static StockTaggedItem createSampleItem({
    String? companyName,
    String? skuCode,
    double? grossWeight,
    double? netWeight,
  }) {
    return StockTaggedItem(
      itemId: 1,
      skuCode: skuCode ?? '27A001',
      lotId: 1,
      lotNumber: '2627-1',
      companyId: 'COMP01',
      branchId: 'HO',
      designerId: 1,
      designerName: 'NATARAJAN SMITH',
      designerAccode: 'ACC01',
      productId: 1,
      productName: 'GOLD RING CASTING',
      subproductId: 1,
      subproductName: 'FLOWER MODEL',
      styleId: 1,
      styleName: 'BOMBAY PLAIN',
      sizeId: 1,
      sizeName: '2.4',
      purityId: 1,
      purityName: '22KT (916)',
      purity: 91.6,
      pcs: 1,
      grossWeight: grossWeight ?? 125.000,
      netWeight: netWeight ?? 120.500,
      stonePcs: 4,
      stoneWeight: 0.850,
      stoneAmt: 1200.0,
      diamondPcs: 12,
      diamondWeight: 1.25,
      diamondAmt: 45000.0,
      boardRate: 7500.0,
      salesVaPercent: 12.0,
      salesWastage: 2.0,
      salesMcPerGram: 150.0,
      salesMCharge: 0.0,
      salesTotalAmt: 98500.0,
      purchaseTouchPct: 94.0,
      purchaseGoldRate: 7400.0,
      purchaseMc: 350.0,
      purchaseStoneCost: 200.0,
      purchaseDiamondCost: 0.0,
      purchaseTotalCost: 89400.0,
      huid: 'HUID916ABC',
      status: 'IN_STOCK',
      companyName: companyName ?? 'PROGOLD JEWELLERY',
      branchName: 'Head Office',
    );
  }

  /// Builds a single PDF label widget based on template and tagged item
  static pw.Widget buildPdfSingleLabel({
    required BarcodeTemplate template,
    required StockTaggedItem item,
    double scale = 1.0,
  }) {
    final widthPt = mmToPt(template.effectiveWidthMm);
    final heightPt = mmToPt(template.effectiveHeightMm);

    return pw.Container(
      width: widthPt,
      height: heightPt,
      padding: pw.EdgeInsets.only(
        top: mmToPt(template.marginTopMm),
        left: mmToPt(template.marginLeftMm),
        right: mmToPt(template.marginLeftMm),
        bottom: mmToPt(template.marginTopMm),
      ),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300, width: 0.3),
      ),
      child: pw.Stack(
        children: template.elements.where((e) => e.isVisible).map((elem) {
          final xPt = mmToPt(elem.xMm);
          final yPt = mmToPt(elem.yMm);
          final elemW = mmToPt(elem.widthMm);
          final elemH = mmToPt(elem.heightMm);

          pw.Widget childWidget;
          if (elem.type == 'barcode_2d') {
            // 2D QR Code
            final qrData = item.skuCode.isNotEmpty ? item.skuCode : 'PROGOLD-SAMPLE';
            childWidget = pw.BarcodeWidget(
              barcode: pw.Barcode.qrCode(),
              data: qrData,
              width: elemW,
              height: elemH,
            );
          } else if (elem.type == 'barcode_1d') {
            // 1D Code128 Barcode
            final bcData = item.skuCode.isNotEmpty ? item.skuCode : 'PROGOLD123';
            childWidget = pw.BarcodeWidget(
              barcode: pw.Barcode.code128(),
              data: bcData,
              width: elemW,
              height: elemH,
              drawText: false,
            );
          } else {
            // Text Element
            final text = formatElementText(elem: elem, item: item);
            if (text.isEmpty) return pw.SizedBox.shrink();

            pw.TextAlign align = pw.TextAlign.left;
            if (elem.alignment == 'center') align = pw.TextAlign.center;
            if (elem.alignment == 'right') align = pw.TextAlign.right;

            childWidget = pw.Container(
              width: elemW,
              height: elemH,
              alignment: elem.alignment == 'center'
                  ? pw.Alignment.center
                  : (elem.alignment == 'right' ? pw.Alignment.centerRight : pw.Alignment.centerLeft),
              child: pw.Text(
                text,
                textAlign: align,
                style: pw.TextStyle(
                  fontSize: elem.fontSize,
                  fontWeight: elem.isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
                ),
                maxLines: 1,
              ),
            );
          }

          return pw.Positioned(
            left: xPt,
            top: yPt,
            child: childWidget,
          );
        }).toList(),
      ),
    );
  }

  /// Generates the raw PDF bytes for printing a list of items
  static Future<Uint8List> generatePdf({
    required BarcodeTemplate template,
    required List<StockTaggedItem> items,
  }) async {
    final pdf = pw.Document();

    final labelWidthPt = mmToPt(template.effectiveWidthMm);
    final labelHeightPt = mmToPt(template.effectiveHeightMm);
    final gapPt = mmToPt(template.gapMm);
    final labelsPerRow = template.labelsPerRow;

    final pageWidthPt = labelsPerRow == 2 ? (labelWidthPt * 2) + gapPt : labelWidthPt;
    final pageHeightPt = labelHeightPt;

    final pageFormat = PdfPageFormat(
      pageWidthPt,
      pageHeightPt,
      marginAll: 0,
    );

    if (labelsPerRow == 1) {
      for (final item in items) {
        pdf.addPage(
          pw.Page(
            pageFormat: pageFormat,
            build: (pw.Context context) {
              return buildPdfSingleLabel(template: template, item: item);
            },
          ),
        );
      }
    } else {
      // 2 Labels across
      for (int i = 0; i < items.length; i += 2) {
        final item1 = items[i];
        final item2 = (i + 1 < items.length) ? items[i + 1] : null;

        pdf.addPage(
          pw.Page(
            pageFormat: pageFormat,
            build: (pw.Context context) {
              return pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.start,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  buildPdfSingleLabel(template: template, item: item1),
                  if (item2 != null) ...[
                    pw.SizedBox(width: gapPt),
                    buildPdfSingleLabel(template: template, item: item2),
                  ] else ...[
                    pw.SizedBox(width: gapPt),
                    pw.SizedBox(width: labelWidthPt, height: labelHeightPt),
                  ],
                ],
              );
            },
          ),
        );
      }
    }

    return await pdf.save();
  }

  /// Direct print layout dialog invoking native printer spooler
  static Future<void> directPrint({
    required BarcodeTemplate template,
    required List<StockTaggedItem> items,
    String jobName = 'ProGold_Barcode_Print',
  }) async {
    final pdfBytes = await generatePdf(template: template, items: items);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: jobName,
    );
  }
}
