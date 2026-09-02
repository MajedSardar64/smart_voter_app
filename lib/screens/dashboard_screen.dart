import 'package:flutter/material.dart';

import '../services/db_service.dart';
import '../utils/bangla_helper.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FutureBuilder<Map<String, dynamic>>(
      future: DBService.instance.getDashboardStats(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF00695C)),
          );
        }

        final data = snapshot.data!;
        final totalVoters = BanglaHelper.toBanglaDigits(
          data['totalVoters'].toString(),
        );
        final totalAreas = BanglaHelper.toBanglaDigits(
          data['totalAreas'].toString(),
        );
        final totalCenters = BanglaHelper.toBanglaDigits(
          data['totalCenters'].toString(),
        );
        final List<Map<String, dynamic>> areaBreakdown =
            List<Map<String, dynamic>>.from(data['areaBreakdown']);
        final List<Map<String, dynamic>> centerBreakdown =
            List<Map<String, dynamic>>.from(data['centerBreakdown']);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'তথ্য',
                style: TextStyle(
                  fontSize: 18,
                  color: Color(0xFF1976D2),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              _summaryRow('মোট ভোটার', totalVoters),
              const Divider(),
              _summaryRow('মোট ভোটার এলাকা', '$totalAreas টি'),
              const Divider(),
              _summaryRow('মোট কেন্দ্র', totalCenters),
              const Divider(),
              _summaryRow(
                'মাইগ্রেট ভোটার',
                '০',
              ), // মাইগ্রেট ভোটার বাতিল, জিরো (0)
              const SizedBox(height: 25),

              const Text(
                'এলাকা ভিত্তিক ভোটার সংখ্যা',
                style: TextStyle(
                  fontSize: 18,
                  color: Color(0xFF1976D2),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),

              Table(
                border: TableBorder.all(
                  color: isDark ? Colors.white24 : Colors.grey.shade400,
                ),
                columnWidths: const {
                  0: FlexColumnWidth(2.5),
                  1: FlexColumnWidth(1.2),
                  2: FlexColumnWidth(1.2),
                  3: FlexColumnWidth(1.2),
                },
                children: [
                  _buildTableRow(
                    ['এলাকা', 'পুরুষ/মহিলা', 'ভোটার সংখ্যা', 'মোট'],
                    isHeader: true,
                    isDark: isDark,
                  ),
                  for (var row in areaBreakdown) ...[
                    _buildTableRow([
                      row['area'].toString(),
                      'পুরুষ',
                      BanglaHelper.toBanglaDigits(row['maleCount'].toString()),
                      BanglaHelper.toBanglaDigits(row['total'].toString()),
                    ], isDark: isDark),
                    _buildTableRow([
                      row['area'].toString(),
                      'মহিলা',
                      BanglaHelper.toBanglaDigits(
                        row['femaleCount'].toString(),
                      ),
                      '',
                    ], isDark: isDark),
                    if ((row['hijraCount'] ?? 0) > 0)
                      _buildTableRow([
                        row['area'].toString(),
                        'হিজড়া',
                        BanglaHelper.toBanglaDigits(
                          row['hijraCount'].toString(),
                        ),
                        '',
                      ], isDark: isDark),
                  ],
                ],
              ),
              const SizedBox(height: 30),

              const Text(
                'কেন্দ্র ভিত্তিক ভোটার সংখ্যা',
                style: TextStyle(
                  fontSize: 18,
                  color: Color(0xFFE53935),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),

              Table(
                border: TableBorder.all(
                  color: isDark ? Colors.white24 : Colors.grey.shade400,
                ),
                columnWidths: const {
                  0: FlexColumnWidth(3.0),
                  1: FlexColumnWidth(1.0),
                  2: FlexColumnWidth(1.2),
                  3: FlexColumnWidth(1.2),
                },
                children: [
                  _buildTableRow(
                    ['এলাকা / কেন্দ্র', 'থেকে', 'পর্যন্ত', 'ভোটার সংখ্যা'],
                    isHeader: true,
                    isDark: isDark,
                  ),
                  for (var row in centerBreakdown)
                    _buildTableRow(
                      [
                        row['center'].toString(),
                        BanglaHelper.toBanglaDigits(
                          row['startSerial'].toString(),
                        ),
                        BanglaHelper.toBanglaDigits(
                          row['endSerial'].toString(),
                        ),
                        BanglaHelper.toBanglaDigits(
                          row['totalCount'].toString(),
                        ),
                      ],
                      isCenterTable: true,
                      isDark: isDark,
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _summaryRow(String title, String count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 15)),
          Text(
            count,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  TableRow _buildTableRow(
    List<String> cells, {
    bool isHeader = false,
    bool isCenterTable = false,
    bool isDark = false,
  }) {
    return TableRow(
      decoration: BoxDecoration(
        color: isHeader
            ? (isDark
                  ? const Color(0xFF334155)
                  : const Color(0xFFB0BEC5).withValues(alpha: 0.5))
            : Colors.transparent,
      ),
      children: cells.map((cell) {
        return Padding(
          padding: const EdgeInsets.all(6),
          child: Text(
            cell,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
              color: isCenterTable && !isHeader && cell.contains('(')
                  ? const Color(0xFFE11D48)
                  : null,
            ),
          ),
        );
      }).toList(),
    );
  }
}
