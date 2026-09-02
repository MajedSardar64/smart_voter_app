import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/candidate.dart';
import '../models/voter.dart';
import '../services/db_service.dart';
import '../utils/bangla_helper.dart';
import '../utils/slip_share_helper.dart';

class VoterDetailScreen extends StatefulWidget {
  final Voter voter;
  const VoterDetailScreen({super.key, required this.voter});

  @override
  State<VoterDetailScreen> createState() => _VoterDetailScreenState();
}

class _VoterDetailScreenState extends State<VoterDetailScreen> {
  Candidate? _candidate;
  final GlobalKey _thermalPrintKey = GlobalKey();

  final String softwareFooterInfo = 'এইসিস.আইটি, ঢাকা। মোবাইল: ০১৬২৪১৫৬৫৮৫';
  final String thermalFooterInfo = 'এ.ই.সিস আইটি, ঢাকা, ০১৬২৪১৫৬৫৮৫';

  @override
  void initState() {
    super.initState();
    _loadCandidate();
  }

  void _loadCandidate() async {
    final cand = await AuthService.getActiveCandidate();
    if (!mounted) return;
    setState(() => _candidate = cand);
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
      print('Thermal slip capture error: $e');
      return null;
    }
  }

  // ১. PRINT বাটন (পোর্টেবল ব্লুটুথ থার্মাল প্রিন্টারে লম্বালম্বি প্রিন্ট)
  void _printThermalDirect() async {
    final bytes = await _captureThermalSlipBytes();
    if (bytes == null) return;

    final base64String = base64Encode(bytes);
    final rawBtUrl = Uri.parse("rawbt:data:image/png;base64,$base64String");

    if (await canLaunchUrl(rawBtUrl)) {
      await launchUrl(rawBtUrl);
    } else {
      _printNormalPdf();
    }
  }

  // ২. PDF প্রিন্ট (সিস্টেম / ওয়াইফাই / A4 প্রিন্ট)
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
    final msg = Uri.encodeComponent(
      '${_candidate?.electionTitle ?? "নির্বাচন"}: প্রার্থী: ${_candidate?.name ?? ""} (${_candidate?.symbolName ?? ""} মার্কা)\n'
      'ভোটার: ${widget.voter.name}\nক্রমিক: ${BanglaHelper.toBanglaDigits(widget.voter.serialNo)}\nকেন্দ্র: ${widget.voter.centerName}',
    );
    final url = Uri.parse('sms:?body=$msg');
    if (await canLaunchUrl(url)) await launchUrl(url);
  }

  void _shareSlipAsImage() {
    SlipShareHelper.captureAndShareSlip(_thermalPrintKey, widget.voter.name);
  }

  void _copyAllVoterInfo() {
    String banglaDob = BanglaHelper.formatDobToBangla(widget.voter.dob);
    String banglaGender = BanglaHelper.formatGender(widget.voter.gender);

    String textToCopy =
        '''
ভোট কেন্দ্র: ${widget.voter.centerName}
সিরিয়াল নাম্বার: ${BanglaHelper.toBanglaDigits(widget.voter.serialNo)}
নাম: ${widget.voter.name}
ভোটার নং- ${BanglaHelper.toBanglaDigits(widget.voter.voterNo)}, লিঙ্গ: $banglaGender
পেশা: ${widget.voter.occupation}
জন্ম তারিখ: $banglaDob
পিতা/স্বামী: ${widget.voter.fatherOrHusband}
মাতা: ${widget.voter.mother}
ঠিকানা: ${widget.voter.address}
এলাকা: ${widget.voter.area}
ওয়ার্ড: ${BanglaHelper.toBanglaDigits(widget.voter.displayWard)}
'''
            .trim();

    Clipboard.setData(ClipboardData(text: textToCopy));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('ভোটারের সম্পূর্ণ তথ্য সফলভাবে কপি করা হয়েছে!'),
        backgroundColor: Color(0xFF00695C),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _openFamilySearch() async {
    final family = await DBService.instance.searchFamily(widget.voter);
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'একই পরিবারের অন্যান্য ভোটার',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            family.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('কোন সদস্য পাওয়া যায়নি'),
                    ),
                  )
                : Expanded(
                    child: ListView.builder(
                      itemCount: family.length,
                      itemBuilder: (ctx, i) => ListTile(
                        title: Text(
                          family[i].name,
                          style: const TextStyle(
                            color: Color(0xFF2563EB),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          'পিতা/স্বামী: ${family[i].fatherOrHusband} | মাতা: ${family[i].mother}',
                        ),
                        onTap: () {
                          Navigator.pop(ctx);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  VoterDetailScreen(voter: family[i]),
                            ),
                          );
                        },
                      ),
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
      if (path.startsWith('http')) {
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
      if (path.startsWith('http')) {
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String banglaDob = BanglaHelper.formatDobToBangla(widget.voter.dob);
    String banglaGender = BanglaHelper.formatGender(widget.voter.gender);
    String banglaSerial = BanglaHelper.toBanglaDigits(widget.voter.serialNo);
    String banglaVoterNo = BanglaHelper.toBanglaDigits(widget.voter.voterNo);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ভোটার তথ্য',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: Stack(
        children: [
          // =========================================================================
          // ১. মোবাইলের স্ক্রিনে দৃশ্যমান UI (অরিজিনাল ডিজাইন)
          // =========================================================================
          SingleChildScrollView(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 8, 6, 2),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _actionBtn(
                            'PRINT',
                            const Color(0xFF22262B),
                            Icons.print,
                            _printThermalDirect,
                          ),
                          _actionBtn(
                            'PDF প্রিন্ট',
                            const Color(0xFF005652),
                            Icons.picture_as_pdf,
                            _printNormalPdf,
                          ),
                          _actionBtn(
                            'SMS',
                            const Color(0xFFF4334C),
                            Icons.sms,
                            _sendSms,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _actionBtn(
                            'SHARE',
                            const Color(0xFF059669),
                            Icons.share,
                            _shareSlipAsImage,
                          ),
                          _actionBtn(
                            'COPY',
                            const Color(0xFF0891B2),
                            Icons.copy,
                            _copyAllVoterInfo,
                          ),
                          _actionBtn(
                            'FAMILY',
                            const Color(0xFF2F76F6),
                            Icons.family_restroom,
                            _openFamilySearch,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  child: Text(
                    'প্রিন্ট করার জন্য প্লে-স্টোর থেকে "RawBT" ডাউনলোড করে আপনার প্রিন্টার কানেক্ট করে নিন।',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: isDark ? Colors.white60 : Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 4),

                // মোবাইল ডিসপ্লে কার্ড
                Container(
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
                      Container(
                        height: 155,
                        width: double.infinity,
                        decoration: const BoxDecoration(
                          color: Color(0xFF004D40),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Positioned(
                              top: 48,
                              bottom: 48,
                              left: 0,
                              right: 0,
                              child: Container(color: const Color(0xFF9FB0B5)),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 125,
                                  height: 125,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.black87,
                                      width: 2.5,
                                    ),
                                    color: Colors.white,
                                  ),
                                  child: ClipOval(
                                    child: _buildImage(
                                      _candidate?.candidateImage,
                                      width: 125,
                                      height: 125,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  width: 125,
                                  height: 125,
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.black87,
                                      width: 2.5,
                                    ),
                                    color: Colors.white,
                                  ),
                                  child: ClipOval(
                                    child: _buildSymbolImage(
                                      _candidate?.symbolImage,
                                      width: 125,
                                      height: 125,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.fromLTRB(6, 6, 6, 4),
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.black87, width: 1.5),
                        ),
                        child: Text(
                          '${_candidate?.name ?? "মুহাম্মদ সাইদুল ইসলাম"} কে ${_candidate?.symbolName ?? "তালা"} মার্কায় ভোট দিন',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                            color: Colors.black,
                          ),
                        ),
                      ),

                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        color: const Color(0xFF004D40),
                        child: Text(
                          'কেন্দ্র: ${widget.voter.centerName}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                          ),
                        ),
                      ),

                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.fromLTRB(6, 0, 6, 6),
                        padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
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
                            _slipRow('পেশা:', widget.voter.occupation),
                            _slipRow('জন্ম তারিখ:', banglaDob),
                            _slipRow(
                              'পিতা/স্বামী:',
                              widget.voter.fatherOrHusband,
                            ),
                            _slipRow('মাতা:', widget.voter.mother),
                            _slipRow('ঠিকানা:', widget.voter.address),
                            _slipRow('এলাকা:', widget.voter.area),
                            _slipRow(
                              'ওয়ার্ড:',
                              BanglaHelper.toBanglaDigits(
                                widget.voter.displayWard,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Center(
                              child: Text(
                                softwareFooterInfo,
                                style: const TextStyle(
                                  fontStyle: FontStyle.italic,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12.5,
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
                const SizedBox(height: 20),
              ],
            ),
          ),

          // =========================================================================
          // ২. 🔴 সম্পূর্ণ উপর থেকে নিচে লম্বালম্বি থার্মাল প্রিন্ট স্লিপ (Vertical POS Format)
          // =========================================================================
          Transform.translate(
            offset: const Offset(
              -10000,
              -10000,
            ), // স্ক্রিনে অদৃশ্য থাকবে, প্রিন্টারে হুবহু এটি যাবে
            child: RepaintBoundary(
              key: _thermalPrintKey,
              child: Container(
                width:
                    380, // থার্মাল পেপার রোলের আসল প্রস্থ (৫৮ মিমি / ৮০ মিমি)
                padding: const EdgeInsets.all(6),
                color: Colors.white,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ১. শীর্ষ অংশ: প্রার্থীর বক্স (উপরে)
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black, width: 1.2),
                      ),
                      child: Column(
                        children: [
                          Text(
                            _candidate?.electionTitle ?? 'নির্বাচন ২০২৪',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: Colors.black,
                            ),
                          ),
                          Text(
                            _candidate?.postTitle ?? 'পদপ্রার্থী',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 2),
                          RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 13,
                                fontFamily: 'Hind Siliguri',
                              ),
                              children: [
                                TextSpan(
                                  text: '${_candidate?.name ?? ""} ',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const TextSpan(text: 'কে\n'),
                                TextSpan(
                                  text:
                                      '${_candidate?.symbolName ?? ""} মার্কায় ',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const TextSpan(text: 'ভোট দিন'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 100,
                                height: 95,
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.black54),
                                ),
                                child: _buildImage(
                                  _candidate?.candidateImage,
                                  width: 100,
                                  height: 95,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Container(
                                width: 75,
                                height: 95,
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.black54),
                                ),
                                child: _buildSymbolImage(
                                  _candidate?.symbolImage,
                                  width: 75,
                                  height: 95,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // ২. মাঝখানের অনুভূমিক কাটার দাগ (✂️)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(height: 1, color: Colors.black54),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 6),
                            child: Text('✂️', style: TextStyle(fontSize: 13)),
                          ),
                          Expanded(
                            child: Container(height: 1, color: Colors.black54),
                          ),
                        ],
                      ),
                    ),

                    // ৩. নিচের অংশ: ভোটারের তথ্য বক্স (নিচে)
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black, width: 1.2),
                      ),
                      child: Stack(
                        children: [
                          if (_candidate?.symbolImage != null)
                            Positioned.fill(
                              child: Opacity(
                                opacity: 0.12,
                                child: Center(
                                  child: _buildSymbolImage(
                                    _candidate?.symbolImage,
                                    width: 120,
                                    height: 120,
                                  ),
                                ),
                              ),
                            ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'কেন্দ্রঃ ${widget.voter.centerName}   এলাকাঃ ${widget.voter.area}',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                                maxLines: 2,
                              ),
                              const Divider(
                                color: Colors.black,
                                thickness: 1,
                                height: 6,
                              ),
                              RichText(
                                text: TextSpan(
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 13,
                                    fontFamily: 'Hind Siliguri',
                                  ),
                                  children: [
                                    TextSpan(
                                      text: '$banglaSerial. ',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const TextSpan(text: 'নামঃ '),
                                    TextSpan(
                                      text: widget.voter.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 2),
                              _thermalLine(
                                'ভোটার নং:',
                                '$banglaVoterNo (লিঙ্গ: $banglaGender)',
                              ),
                              _thermalLine('পেশা:', widget.voter.occupation),
                              _thermalLine('জন্মঃ', banglaDob),
                              _thermalLine(
                                'পিতা/স্বামী:',
                                widget.voter.fatherOrHusband,
                              ),
                              _thermalLine('মাতাঃ', widget.voter.mother),
                              _thermalLine('ঠিকানাঃ', widget.voter.address),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),

                    // ৪. ফুটার
                    Center(
                      child: Text(
                        thermalFooterInfo,
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: Colors.black87,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _thermalLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label ',
            style: const TextStyle(fontSize: 11.5, color: Colors.black),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 11.5,
                color: Colors.black,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _slipRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label ',
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionBtn(
    String title,
    Color color,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        child: ElevatedButton.icon(
          onPressed: onTap,
          icon: Icon(icon, size: 13, color: Colors.white),
          label: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(5),
            ),
            elevation: 1,
          ),
        ),
      ),
    );
  }
}
