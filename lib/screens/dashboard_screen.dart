import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/candidate.dart';
import '../services/db_service.dart';
import '../utils/bangla_helper.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  Future<Map<String, dynamic>> _getDashboardData() async {
    if (!kIsWeb) {
      return await DBService.instance.getDashboardStats();
    }

    final cand = await AuthService.getActiveCandidate();
    if (cand == null) {
      return {
        'totalVoters': 0,
        'totalAreas': 0,
        'totalCenters': 0,
        'migratedVoters': 0,
        'publicationDates': [],
        'areaBreakdown': [],
        'centerBreakdown': [],
      };
    }

    int totalAreas = cand.assignedWards.length;
    int totalCenters = cand.assignedWards.map((w) => w.wardNo).toSet().length;
    int totalVoters = cand.totalVoters > 0
        ? cand.totalVoters
        : cand.assignedWards.fold(0, (sum, w) => sum + w.totalVoters);

    return {
      'totalVoters': totalVoters,
      'totalAreas': totalAreas,
      'totalCenters': totalCenters,
      'migratedVoters': 0,
      'publicationDates': [],
      'areaBreakdown': [],
      'centerBreakdown': [],
    };
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FutureBuilder<Map<String, dynamic>>(
      future: _getDashboardData(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF00695C)),
          );
        }

        final data = snapshot.data!;
        final int totalVotersInt =
            int.tryParse(data['totalVoters']?.toString() ?? '0') ?? 0;
        final int migratedVotersInt =
            int.tryParse((data['migratedVoters'] ?? 0).toString()) ?? 0;
        final int totalWithMigratedInt = totalVotersInt + migratedVotersInt;

        final totalVoters = BanglaHelper.toBanglaDigits(
          totalVotersInt.toString(),
        );
        final totalWithMigrated = BanglaHelper.toBanglaDigits(
          totalWithMigratedInt.toString(),
        );
        final totalAreas = BanglaHelper.toBanglaDigits(
          data['totalAreas'].toString(),
        );
        final totalCenters = BanglaHelper.toBanglaDigits(
          data['totalCenters'].toString(),
        );
        final totalMigrated = BanglaHelper.toBanglaDigits(
          migratedVotersInt.toString(),
        );

        // 🔴 প্রকাশের তারিখসমূহ
        final List pubDatesList = data['publicationDates'] ?? [];
        final String pubDatesStr = pubDatesList.isNotEmpty
            ? pubDatesList
                  .map((d) => BanglaHelper.toBanglaDigits(d.toString()))
                  .join(', ')
            : 'তথ্য নেই';

        final List<Map<String, dynamic>> areaBreakdown =
            List<Map<String, dynamic>>.from(data['areaBreakdown'] ?? []);
        final List<Map<String, dynamic>> centerBreakdown =
            List<Map<String, dynamic>>.from(data['centerBreakdown'] ?? []);

        return ValueListenableBuilder<Candidate?>(
          valueListenable: AuthService.activeCandidateNotifier,
          builder: (context, candidate, _) {
            final bool canShowCenters = candidate?.showPollingCenter != false;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(12),
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
                  const SizedBox(height: 8),
                  _summaryRow('মোট ভোটার', totalVoters),
                  const Divider(),
                  _summaryRow(
                    'মাইগ্রেট সহ মোট ভোটার সংখ্যা',
                    totalWithMigrated,
                  ),
                  const Divider(),
                  _summaryRow('মোট ভোটার এলাকা', '$totalAreas টি'),
                  const Divider(),
                  _summaryRow(
                    'মোট ভোটকেন্দ্র',
                    canShowCenters ? '$totalCenters টি' : 'অপ্রকাশিত',
                  ),
                  const Divider(),
                  _summaryRow('মাইগ্রেট ভোটার', totalMigrated),
                  const Divider(),
                  // 🔴 ড্যাশবোর্ডে ভোটার তালিকা প্রকাশের তারিখ প্রদর্শন
                  _summaryRow('ভোটার তালিকা প্রকাশের তারিখ', pubDatesStr),
                  const SizedBox(height: 20),

                  const Text(
                    'এলাকা ভিত্তিক ভোটার সংখ্যা',
                    style: TextStyle(
                      fontSize: 16.5,
                      color: Color(0xFF1976D2),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

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
                          BanglaHelper.toBanglaDigits(
                            row['maleCount'].toString(),
                          ),
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
                      ],
                    ],
                  ),
                  const SizedBox(height: 25),

                  const Text(
                    'ভোটকেন্দ্র ও এলাকা ভিত্তিক ভোটার ক্রমিক (রেঞ্জ)',
                    style: TextStyle(
                      fontSize: 16.5,
                      color: Color(0xFFE53935),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  if (!canShowCenters)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade300),
                      ),
                      child: const Center(
                        child: Text(
                          'অ্যাডমিন প্যানেল থেকে এই প্রার্থীর জন্য ভোট কেন্দ্র সংক্রান্ত তথ্য প্রদর্শন বন্ধ রাখা হয়েছে।',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.orange,
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    )
                  else if (centerBreakdown.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: const Center(
                        child: Text(
                          'কোনো ভোটকেন্দ্রের তথ্য সংরক্ষিত নেই। সেটিংস থেকে এলাকা ডাউনলোড/সিঙ্ক করুন।',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, fontSize: 12.5),
                        ),
                      ),
                    )
                  else
                    Table(
                      border: TableBorder.all(
                        color: isDark ? Colors.white24 : Colors.grey.shade400,
                      ),
                      columnWidths: const {
                        0: FlexColumnWidth(2.8),
                        1: FlexColumnWidth(1.0),
                        2: FlexColumnWidth(1.0),
                        3: FlexColumnWidth(1.3),
                      },
                      children: [
                        _buildTableRow(
                          [
                            'ভোটকেন্দ্র ও এলাকা',
                            'থেকে',
                            'পর্যন্ত',
                            'মোট ভোটার',
                          ],
                          isHeader: true,
                          isDark: isDark,
                        ),
                        for (var row in centerBreakdown) ...[
                          () {
                            String serialPrefix = '';
                            final sRaw =
                                row['centerSerial']?.toString().trim() ?? '';
                            if (sRaw.isNotEmpty) {
                              serialPrefix =
                                  '[ক্রমিক: ${BanglaHelper.toBanglaDigits(sRaw)}] ';
                            }

                            final booths =
                                row['boothsCount'] != null &&
                                    row['boothsCount'].toString().isNotEmpty
                                ? ' • বুথ: ${BanglaHelper.toBanglaDigits(row['boothsCount'].toString())}'
                                : '';

                            final centerCellText =
                                '$serialPrefix${row['center']} • [${row['gender'] ?? 'পুরুষ'}]\n[এলাকা: ${row['area'] ?? ''}]$booths';

                            return _buildTableRow(
                              [
                                centerCellText,
                                BanglaHelper.toBanglaDigits(
                                  row['startSerial'].toString(),
                                ),
                                BanglaHelper.toBanglaDigits(
                                  row['endSerial'].toString(),
                                ),
                                '${BanglaHelper.toBanglaDigits(row['totalCount'].toString())}${row['migratedCount'] != null && (row['migratedCount'] as int) > 0 ? "\n(মাইগ্রেট: ${BanglaHelper.toBanglaDigits(row['migratedCount'].toString())})" : ""}',
                              ],
                              isCenterTable: true,
                              isDark: isDark,
                            );
                          }(),
                        ],
                      ],
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _summaryRow(String title, String count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(title, style: const TextStyle(fontSize: 14))),
          const SizedBox(width: 8),
          Text(
            count,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
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
                  : const Color(0xFFB0BEC5).withOpacity(0.5))
            : Colors.transparent,
      ),
      children: cells.map((cell) {
        final isMale = cell.contains('[পুরুষ]');
        final isFemale = cell.contains('[মহিলা]');
        final isHijra = cell.contains('[হিজড়া]');

        Color? textColor;
        if (isCenterTable && !isHeader) {
          if (isMale) textColor = const Color(0xFF1D4ED8);
          if (isFemale) textColor = const Color(0xFFBE185D);
          if (isHijra) textColor = const Color(0xFFD97706);
        }

        return Padding(
          padding: const EdgeInsets.all(5),
          child: Text(
            cell,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
              color: textColor,
            ),
          ),
        );
      }).toList(),
    );
  }
}
