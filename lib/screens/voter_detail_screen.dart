import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/candidate.dart';
import '../models/voter.dart';
import '../services/api_service.dart';
import '../services/db_service.dart';
import '../utils/bangla_helper.dart';
import '../utils/slip_share_helper.dart';
import '../widgets/voter_print_slip.dart';

class VoterDetailScreen extends StatefulWidget {
  final Voter voter;
  const VoterDetailScreen({super.key, required this.voter});

  @override
  State<VoterDetailScreen> createState() => _VoterDetailScreenState();
}

class _VoterDetailScreenState extends State<VoterDetailScreen> {
  Candidate? _candidate;
  final GlobalKey _thermalPrintKey = GlobalKey();
  final GlobalKey _screenCardKey = GlobalKey();
  String _slipFormat = 'format_1';

  final String softwareFooterInfo = 'সরদার আইটি, ঢাকা। মোবাইল: ০১৬১৯০৯৭৫৭১';
  final String thermalFooterInfo = 'সরদার আইটি, ঢাকা, ০১৬১৯০৯৭৫৭১';

  @override
  void initState() {
    super.initState();
    _loadCandidateAndSettings();
  }

  void _loadCandidateAndSettings() async {
    final cand = await AuthService.getActiveCandidate();
    final prefs = await SharedPreferences.getInstance();
    final format = prefs.getString('voter_slip_format') ?? 'format_1';
    if (!mounted) return;
    setState(() {
      _candidate = cand;
      _slipFormat = format;
    });
  }

  Future<Uint8List?> _captureThermalSlipBytes() async {
    try {
      RenderRepaintBoundary boundary =
          _thermalPrintKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      return null;
    }
  }

  void _handleSmartPrint() async {
    final prefs = await SharedPreferences.getInstance();
    final bool isThermal = prefs.getBool('is_thermal_printer_enabled') ?? true;

    if (isThermal && !kIsWeb) {
      final bytes = await _captureThermalSlipBytes();
      if (bytes == null) return;

      final base64String = base64Encode(bytes);
      final rawBtUrl = Uri.parse("rawbt:data:image/png;base64,$base64String");

      if (await canLaunchUrl(rawBtUrl)) {
        await launchUrl(rawBtUrl);
      } else {
        _printNormalPdf();
      }
    } else {
      _printNormalPdf();
    }
  }

  void _printNormalPdf() async {
    final bytes = await _captureThermalSlipBytes();
    if (bytes == null) return;

    final doc = pw.Document();
    final image = pw.MemoryImage(bytes);

    doc.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(
          80 * PdfPageFormat.mm,
          double.infinity,
          marginAll: 2 * PdfPageFormat.mm,
        ),
        build: (pw.Context context) =>
            pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain)),
      ),
    );

    await Printing.layoutPdf(
      name: 'voter_slip_${widget.voter.serialNo}.pdf',
      onLayout: (PdfPageFormat format) async => doc.save(),
    );
  }

  void _sendSms() async {
    final showCenter =
        _candidate?.showPollingCenter != false &&
        widget.voter.centerName.isNotEmpty &&
        widget.voter.centerName != 'অনির্ধারিত কেন্দ্র';
    final centerDesc = showCenter
        ? '\nকেন্দ্র: ${widget.voter.fullCenterInfo}'
        : '';

    final msg = Uri.encodeComponent(
      '${_candidate?.electionTitle ?? "নির্বাচন"}: প্রার্থী: ${_candidate?.name ?? ""} (${_candidate?.symbolName ?? ""} মার্কা)\n'
      'তারিখ: ${_candidate?.electionDate ?? ""}\n'
      'ভোটার: ${widget.voter.name}\nক্রমিক: ${BanglaHelper.toBanglaDigits(widget.voter.serialNo)}$centerDesc',
    );
    final url = Uri.parse('sms:?body=$msg');
    if (await canLaunchUrl(url)) await launchUrl(url);
  }

  void _shareSlipAsImage() {
    SlipShareHelper.captureAndShareSlip(_screenCardKey, widget.voter.name);
  }

  void _copyAllVoterInfo() {
    String banglaDob = BanglaHelper.formatDobToBangla(widget.voter.dob);
    String banglaGender = BanglaHelper.formatGender(widget.voter.gender);
    final showCenter =
        _candidate?.showPollingCenter != false &&
        widget.voter.centerName.isNotEmpty &&
        widget.voter.centerName != 'অনির্ধারিত কেন্দ্র';
    final centerLine = showCenter
        ? 'ভোট কেন্দ্র: ${widget.voter.fullCenterInfo}\n'
        : '';
    final pubDateLine = widget.voter.publicationDate.isNotEmpty
        ? 'তালিকা প্রকাশ: ${BanglaHelper.toBanglaDigits(widget.voter.publicationDate)}\n'
        : '';

    String textToCopy =
        '''
নির্বাচনের তারিখ: ${_candidate?.electionDate ?? ""}
${centerLine}সিরিয়াল নাম্বার: ${BanglaHelper.toBanglaDigits(widget.voter.serialNo)}
নাম: ${widget.voter.name}
ভোটার নং- ${BanglaHelper.toBanglaDigits(widget.voter.voterNo)}, লিঙ্গ: $banglaGender
জন্ম তারিখ: $banglaDob,   পেশা: ${widget.voter.occupation}
পিতা/স্বামী: ${widget.voter.fatherOrHusband}
মাতা: ${widget.voter.mother}
ঠিকানা: ${widget.voter.address}
এলাকা: ${widget.voter.area}
ওয়ার্ড নং: ${BanglaHelper.toBanglaDigits(widget.voter.displayWard)}
$pubDateLine'''
            .trim();

    Clipboard.setData(ClipboardData(text: textToCopy));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('ভোটারের তথ্য কপি করা হয়েছে!'),
        backgroundColor: Color(0xFF00695C),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // 🔴 ফ্যামিলি সার্চ (মাতার নাম লাইট/ডার্ক উভয় মোডের থিমের সাথে সামঞ্জস্যপূর্ণ)
  void _openFamilySearch() async {
    List<Voter> family = [];

    if (kIsWeb) {
      family = await VoterApiService.searchFamilyOnline(
        widget.voter,
        userId: _candidate?.userId,
      );
    } else {
      family = await DBService.instance.searchFamily(widget.voter);
    }

    if (!mounted) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.65,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'একই পরিবারের অন্যান্য ভোটার',
              style: TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const Divider(),
            family.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'কোন সদস্য পাওয়া যায়নি',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ),
                  )
                : Expanded(
                    child: ListView.builder(
                      itemCount: family.length,
                      itemBuilder: (ctx, i) {
                        final member = family[i];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          title: Text(
                            member.name,
                            style: const TextStyle(
                              color: Color(0xFF2563EB),
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          // 🔴 ডার্ক মোডের ব্যাকগ্রাউন্ড অনুযায়ী পিতা ও মাতার রঙের নিখুঁত সামঞ্জস্য
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'পিতা/স্বামী: ${member.fatherOrHusband}',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: isDark
                                      ? const Color(0xFFCBD5E1)
                                      : const Color(0xFF334155),
                                ),
                              ),
                              if (member.mother.isNotEmpty)
                                Text(
                                  'মাতা: ${member.mother}',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: isDark
                                        ? const Color(0xFFCBD5E1)
                                        : const Color(
                                            0xFF334155,
                                          ), // 🔴 ফিক্সড কালার
                                  ),
                                ),
                              if (_candidate?.showPollingCenter != false &&
                                  member.centerName.isNotEmpty)
                                Text(
                                  'কেন্দ্র: ${member.centerName}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF0D9488),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                            ],
                          ),
                          trailing: Icon(
                            Icons.arrow_forward_ios,
                            size: 14,
                            color: isDark ? Colors.white38 : Colors.grey,
                          ),
                          onTap: () {
                            Navigator.pop(ctx);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    VoterDetailScreen(voter: member),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage(
    String? path, {
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
  }) {
    if (path != null && path.trim().isNotEmpty) {
      if (kIsWeb || path.startsWith('http')) {
        return Image.network(
          path,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (_, __, ___) => Icon(
            Icons.person,
            size: width != null ? width / 2 : 40,
            color: const Color(0xFF004D40),
          ),
        );
      }
      final file = File(path);
      if (file.existsSync()) {
        return Image.file(
          file,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (_, __, ___) => Icon(
            Icons.person,
            size: width != null ? width / 2 : 40,
            color: const Color(0xFF004D40),
          ),
        );
      }
    }
    return Icon(
      Icons.person,
      size: width != null ? width / 2 : 40,
      color: const Color(0xFF004D40),
    );
  }

  Widget _buildSymbolImage(
    String? path, {
    double? width,
    double? height,
    BoxFit fit = BoxFit.contain,
  }) {
    if (path != null && path.trim().isNotEmpty) {
      if (kIsWeb || path.startsWith('http')) {
        return Image.network(
          path,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (_, __, ___) => Icon(
            Icons.how_to_vote,
            size: width != null ? width / 2 : 40,
            color: Colors.black87,
          ),
        );
      }
      final file = File(path);
      if (file.existsSync()) {
        return Image.file(
          file,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (_, __, ___) => Icon(
            Icons.how_to_vote,
            size: width != null ? width / 2 : 40,
            color: Colors.black87,
          ),
        );
      }
    }
    return Icon(
      Icons.lock,
      size: width != null ? width / 2 : 40,
      color: Colors.black87,
    );
  }

  Widget _actionTile({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: Colors.white),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Bangla',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String banglaDob = BanglaHelper.formatDobToBangla(widget.voter.dob);
    String banglaGender = BanglaHelper.formatGender(widget.voter.gender);
    String banglaSerial = BanglaHelper.toBanglaDigits(widget.voter.serialNo);
    String banglaVoterNo = BanglaHelper.toBanglaDigits(widget.voter.voterNo);

    final bool canShowCenter =
        _candidate?.showPollingCenter != false &&
        widget.voter.centerName.isNotEmpty &&
        widget.voter.centerName != 'অনির্ধারিত কেন্দ্র';

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ভোটার তথ্য',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 6, 4, 3),
                  child: Row(
                    children: [
                      _actionTile(
                        label: 'প্রিন্ট',
                        icon: Icons.print,
                        color: const Color(0xFF22262B),
                        onTap: _handleSmartPrint,
                      ),
                      _actionTile(
                        label: 'শেয়ার',
                        icon: Icons.share,
                        color: const Color(0xFF059669),
                        onTap: _shareSlipAsImage,
                      ),
                      _actionTile(
                        label: 'SMS',
                        icon: Icons.sms,
                        color: const Color(0xFFF4334C),
                        onTap: _sendSms,
                      ),
                      _actionTile(
                        label: 'কপি',
                        icon: Icons.copy,
                        color: const Color(0xFF0891B2),
                        onTap: _copyAllVoterInfo,
                      ),
                      _actionTile(
                        label: 'পরিবার',
                        icon: Icons.family_restroom,
                        color: const Color(0xFF2F76F6),
                        onTap: _openFamilySearch,
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 1.5,
                  ),
                  child: Text(
                    'প্রিন্ট করার জন্য সেটিংস থেকে প্রিন্টার পেয়ার ও ফরম্যাট সেট করে নিন।',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: isDark ? Colors.white60 : Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 2),

                // অন-স্ক্রিন প্রিভিউ
                RepaintBoundary(
                  key: _screenCardKey,
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(
                        color: const Color(0xFF004D40),
                        width: 3,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          height: 175,
                          width: double.infinity,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Positioned.fill(
                                child: Column(
                                  children: [
                                    Container(height: 4, color: Colors.white),
                                    Container(
                                      height: 24,
                                      color: const Color(0xFF004D40),
                                    ),
                                    Container(height: 2.5, color: Colors.white),
                                    Expanded(
                                      child: Container(
                                        color: const Color(0xFF9FB0B5),
                                      ),
                                    ),
                                    Container(height: 2.5, color: Colors.white),
                                    Container(
                                      height: 24,
                                      color: const Color(0xFF004D40),
                                    ),
                                    Container(height: 4, color: Colors.white),
                                  ],
                                ),
                              ),
                              Center(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 145,
                                      height: 145,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.black87,
                                          width: 2.5,
                                        ),
                                        color: Colors.white,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              0.25,
                                            ),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: ClipOval(
                                        child: _buildImage(
                                          _candidate?.candidateImage,
                                          width: 145,
                                          height: 145,
                                        ),
                                      ),
                                    ),
                                    Transform.translate(
                                      offset: const Offset(-22, 0),
                                      child: Container(
                                        width: 95,
                                        height: 95,
                                        padding: const EdgeInsets.all(5),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.black87,
                                            width: 2.5,
                                          ),
                                          color: Colors.white,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(
                                                0.3,
                                              ),
                                              blurRadius: 6,
                                              offset: const Offset(1, 2),
                                            ),
                                          ],
                                        ),
                                        child: ClipOval(
                                          child: _buildSymbolImage(
                                            _candidate?.symbolImage,
                                            width: 95,
                                            height: 95,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.fromLTRB(6, 6, 6, 4),
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(
                              color: Colors.black87,
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            '${_candidate?.name ?? "মুহাম্মদ সাইদুল ইসলাম"} কে ${_candidate?.symbolName ?? "তালা"} মার্কায় ভোট দিন',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'Bangla',
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.black,
                            ),
                          ),
                        ),

                        if (_candidate?.electionDate != null &&
                            _candidate!.electionDate.trim().isNotEmpty)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            color: const Color(0xFFE0F2F1),
                            child: Text(
                              'নির্বাচনের তারিখ: ${_candidate!.electionDate}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontFamily: 'Bangla',
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF004D40),
                              ),
                            ),
                          ),

                        if (canShowCenter)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.fromLTRB(6, 4, 6, 0),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            color: const Color(0xFF004D40),
                            child: Text(
                              'ভোট কেন্দ্র: ${widget.voter.fullCenterInfo}',
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Bangla',
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13.5,
                                height: 1.2,
                              ),
                            ),
                          ),

                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.fromLTRB(6, 0, 6, 6),
                          padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
                          color: const Color(0xFFA6BDC2),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _slipRow('সিরিয়াল নাম্বার:', banglaSerial),
                              _slipRow('নাম:', widget.voter.name),
                              _slipRow(
                                'ভোটার নং-',
                                '$banglaVoterNo, লিঙ্গ: $banglaGender',
                              ),
                              _slipRow(
                                'জন্ম তারিখ:',
                                '$banglaDob,   পেশা: ${widget.voter.occupation}',
                              ),
                              _slipRow(
                                'পিতা/স্বামী:',
                                widget.voter.fatherOrHusband,
                              ),
                              _slipRow('মাতা:', widget.voter.mother),
                              _slipRow('ঠিকানা:', widget.voter.address),
                              _slipRow('এলাকা:', widget.voter.area),
                              _slipRow(
                                'ওয়ার্ড নং:',
                                BanglaHelper.toBanglaDigits(
                                  widget.voter.displayWard,
                                ),
                              ),
                              if (widget.voter.publicationDate.isNotEmpty)
                                _slipRow(
                                  'তালিকা প্রকাশ:',
                                  BanglaHelper.toBanglaDigits(
                                    widget.voter.publicationDate,
                                  ),
                                ),
                              const SizedBox(height: 6),
                              Center(
                                child: Text(
                                  softwareFooterInfo,
                                  style: const TextStyle(
                                    fontFamily: 'Bangla',
                                    fontStyle: FontStyle.italic,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),

          // অফ-স্ক্রিন প্রিন্ট স্লিপ (ডায়নামিকালি সিলেক্টেড ফরম্যাটে প্রিন্ট হবে)
          Transform.translate(
            offset: const Offset(-10000, -10000),
            child: RepaintBoundary(
              key: _thermalPrintKey,
              child: VoterPrintSlip(
                candidate: _candidate,
                voter: widget.voter,
                footerText: thermalFooterInfo,
                isRotated90: true,
                slipFormat: _slipFormat,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _slipRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 0.6),
      child: SizedBox(
        width: double.infinity,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: RichText(
            maxLines: 1,
            text: TextSpan(
              style: const TextStyle(
                fontFamily: 'Bangla',
                fontSize: 18,
                color: Colors.black87,
                height: 1.15,
              ),
              children: [
                TextSpan(
                  text: '$label ',
                  style: const TextStyle(fontWeight: FontWeight.normal),
                ),
                TextSpan(
                  text: value,
                  style: const TextStyle(fontWeight: FontWeight.normal),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
