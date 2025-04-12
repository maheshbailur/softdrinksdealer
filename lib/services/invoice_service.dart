import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';

class InvoiceService {
  // Add GST rate constant
  final double gstRate = 0.025; // 2.5%

  Future<void> generateInvoice(List<Map<String, dynamic>> transactions) async {
    final pdf = pw.Document();

    // Group transactions by purchaser_name
    final groupedTransactions = groupTransactionsByPurchaser(transactions);

    // Create pages for each purchaser
    groupedTransactions.forEach((purchaserName, purchaserTransactions) {
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (context) {
            return [
              _buildHeader(purchaserName),
              _buildInvoiceTable(purchaserTransactions),
              _buildFooter(purchaserTransactions),
            ];
          },
        ),
      );
    });

    // Save PDF
    final output = await getTemporaryDirectory();
    final date = DateFormat('yyyy-MM-dd_HH-mm').format(DateTime.now());
    final file = File('${output.path}/invoice_$date.pdf');
    await file.writeAsBytes(await pdf.save());

    // Open PDF
    await OpenFile.open(file.path);
  }

  Map<String, List<Map<String, dynamic>>> groupTransactionsByPurchaser(
      List<Map<String, dynamic>> transactions) {
    return groupBy(transactions, (txn) => txn['purchaser_name'] as String);
  }

  pw.Widget _buildHeader(String purchaserName) {
    return pw.Header(
      level: 0,
      child: pw.Column(
        children: [
          pw.Text('INVOICE', 
            style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)
          ),
          pw.SizedBox(height: 10),
          pw.Text('Purchaser: $purchaserName',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)
          ),
          pw.Text('Date: ${DateFormat('dd/MM/yyyy').format(DateTime.now())}'),
          pw.SizedBox(height: 20),
        ],
      ),
    );
  }

  pw.Widget _buildInvoiceTable(List<Map<String, dynamic>> transactions) {
    final subtotal = _calculateSubtotal(transactions);
    final gstAmount = subtotal * gstRate;
    final totalAmount = subtotal + gstAmount;

    return pw.Column(
      children: [
        pw.Table.fromTextArray(
          headers: ['Date', 'Product', 'Quantity', 'Price'],
          data: transactions.where((txn) => txn['type'] == 'OUT').map((txn) {
            return [
              DateFormat('dd/MM/yyyy').format(DateTime.parse(txn['transaction_date'])),
              '${txn['drink_name']} (${txn['manufacturer_name'] ?? 'Unknown'})',
              txn['quantity'].toString(),
              '₹${txn['price'].toString()}',
            ];
          }).toList(),
          border: pw.TableBorder.all(),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          headerDecoration: pw.BoxDecoration(
            color: PdfColors.grey300,
          ),
          cellAlignments: {
            0: pw.Alignment.centerLeft,
            1: pw.Alignment.centerLeft,
            2: pw.Alignment.centerRight,
            3: pw.Alignment.centerRight,
          },
        ),
        pw.SizedBox(height: 20),
        pw.Container(
          alignment: pw.Alignment.centerRight,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Divider(thickness: 0.5),
              pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Text('Subtotal:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(width: 20),
                  pw.Text('₹${subtotal.toStringAsFixed(2)}'),
                ],
              ),
              pw.SizedBox(height: 5),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Text('GST (2.5%):', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(width: 20),
                  pw.Text('₹${gstAmount.toStringAsFixed(2)}'),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Divider(thickness: 0.5),
              pw.SizedBox(height: 10),
            ],
          ),
        ),
      ],
    );
  }

  double _calculateSubtotal(List<Map<String, dynamic>> transactions) {
    return transactions
        .where((txn) => txn['type'] == 'OUT')
        .fold(0.0, (sum, txn) => sum + (txn['price'] as double));
  }

  pw.Widget _buildFooter(List<Map<String, dynamic>> transactions) {
    final subtotal = _calculateSubtotal(transactions);
    final gstAmount = subtotal * gstRate;
    final totalAmount = subtotal + gstAmount;

    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: pw.EdgeInsets.only(top: 20),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Text(
            'Total Amount: ₹${totalAmount.toStringAsFixed(2)}',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}