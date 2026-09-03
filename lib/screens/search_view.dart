import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/candidate.dart';
import '../services/db_service.dart';
import '../utils/bangla_helper.dart';
import 'search_results_screen.dart';

class SearchView extends StatefulWidget {
  final int
  searchMode; // 0: নাম, 1: জন্ম তারিখ, 2: হোল্ডিং, 3: সিরিয়াল, 4: ভোটার নাম্বার
  const SearchView({super.key, required this.searchMode});

  @override
  State<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<SearchView> {
  final _inputController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Candidate? _candidate;

  String _selectedGender = 'সকল';
  String _selectedWard = 'সকল';
  String _selectedArea = 'সকল';

  final List<String> _genders = ['সকল', 'পুরুষ', 'মহিলা', 'হিজড়া'];
  List<String> _wards = ['সকল'];
  List<String> _areas = ['সকল'];

  @override
  void initState() {
    super.initState();
    _loadInitialData();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void didUpdateWidget(covariant SearchView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchMode != widget.searchMode) {
      _inputController.clear();
      _focusNode.unfocus();
      Future.delayed(const Duration(milliseconds: 60), () {
        if (mounted) _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _inputController.dispose();
    super.dispose();
  }

  // 🔴 শুধুমাত্র প্রার্থীর হোয়াইটলিস্টের ওয়ার্ড ও এলাকা দিয়ে ড্রপডাউন পূরণ (Android ও Web উভয়ের জন্য)
  void _loadInitialData() async {
    final candidate = await AuthService.getActiveCandidate();

    List<String> wards = ['সকল'];
    List<String> areas = ['সকল'];

    if (candidate != null) {
      final Set<String> wSet = {'সকল'};
      final Set<String> aSet = {'সকল'};
      for (var w in candidate.assignedWards) {
        if (w.unionOrPouro.isNotEmpty) wSet.add(w.unionOrPouro);
        if (w.wardNo.isNotEmpty && w.wardNo != '0') wSet.add(w.wardNo);
        if (w.areaName.isNotEmpty) aSet.add(w.areaName);
      }
      wards = wSet.toList();
      areas = aSet.toList();
    }

    if (!mounted) return;
    setState(() {
      _candidate = candidate;
      _wards = wards;
      _areas = areas;
    });
  }

  void _onWardChanged(String? newWard) async {
    setState(() {
      _selectedWard = newWard ?? 'সকল';
      _selectedArea = 'সকল';
    });

    List<String> filteredAreas = ['সকল'];

    if (_candidate != null) {
      final Set<String> aSet = {'সকল'};
      for (var w in _candidate!.assignedWards) {
        if (_selectedWard == 'সকল' ||
            w.unionOrPouro == _selectedWard ||
            w.wardNo == _selectedWard) {
          if (w.areaName.isNotEmpty) aSet.add(w.areaName);
        }
      }
      filteredAreas = aSet.toList();
    }

    if (!mounted) return;
    setState(() {
      _areas = filteredAreas;
    });
  }

  void _executeSearch() {
    FocusManager.instance.primaryFocus?.unfocus();
    FocusScope.of(context).unfocus();

    String text = _inputController.text.trim();

    if (widget.searchMode == 0 && text.length < 2) {
      _showNotice('ভোটারের নাম কমপক্ষে ২ অক্ষর হতে হবে!');
      return;
    }
    if (widget.searchMode == 1 && text.length < 10) {
      _showNotice('সম্পূর্ণ জন্ম তারিখ লিখুন (যেমন: ১৫/০৮/১৯৯৫)!');
      return;
    }
    if (widget.searchMode == 2) {
      if (text.isEmpty) {
        _showNotice('হোল্ডিং বা ঠিকানার অংশ লিখুন!');
        return;
      }
      if (RegExp(r'^\d$').hasMatch(text) || RegExp(r'^[০-৯]$').hasMatch(text)) {
        text = '০$text';
        _inputController.text = text;
      }
    }
    if (widget.searchMode == 4 && text.length < 10) {
      _showNotice('সঠিক ভোটার নাম্বার লিখুন!');
      return;
    }

    String filterText = '';
    String? name, dob, serialNo, voterNo, holdingNo;

    if (widget.searchMode == 0) {
      filterText = 'ভোটারের নাম: $text';
      name = text;
    } else if (widget.searchMode == 1) {
      filterText = 'জন্ম তারিখ: $text';
      dob = text;
    } else if (widget.searchMode == 2) {
      filterText = 'ঠিকানা/হোল্ডিং: $text';
      holdingNo = text;
    } else if (widget.searchMode == 3) {
      filterText = 'সিরিয়াল নং: $text';
      serialNo = text;
    } else if (widget.searchMode == 4) {
      filterText = 'ভোটার নাম্বার: $text';
      voterNo = text;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SearchResultsScreen(
          filterText: filterText,
          name: name,
          dob: dob,
          serialNo: serialNo,
          voterNo: voterNo,
          holdingNo: holdingNo,
          gender: _selectedGender,
          ward: _selectedWard,
          area: _selectedArea,
        ),
      ),
    );
  }

  void _showNotice(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _reset() {
    setState(() {
      _inputController.clear();
      _selectedGender = 'সকল';
      _selectedWard = 'সকল';
      _selectedArea = 'সকল';
    });
    _loadInitialData();
  }

  Widget _buildCandidateImage(String? path) {
    if (path != null && path.trim().isNotEmpty) {
      if (kIsWeb || path.startsWith('http')) {
        return ClipOval(
          child: Image.network(
            path,
            fit: BoxFit.cover,
            width: 75,
            height: 75,
            errorBuilder: (_, __, ___) =>
                const Icon(Icons.person, size: 45, color: Colors.teal),
          ),
        );
      }
      final file = File(path);
      if (file.existsSync()) {
        return ClipOval(
          child: Image.file(
            file,
            fit: BoxFit.cover,
            width: 75,
            height: 75,
            errorBuilder: (_, __, ___) =>
                const Icon(Icons.person, size: 45, color: Colors.teal),
          ),
        );
      }
    }
    return const Icon(Icons.person, size: 45, color: Colors.teal);
  }

  Widget _buildSymbolImage(String? path) {
    if (path != null && path.trim().isNotEmpty) {
      if (kIsWeb || path.startsWith('http')) {
        return ClipOval(
          child: Image.network(
            path,
            fit: BoxFit.contain,
            width: 75,
            height: 75,
            errorBuilder: (_, __, ___) =>
                const Icon(Icons.lock, size: 45, color: Colors.black87),
          ),
        );
      }
      final file = File(path);
      if (file.existsSync()) {
        return ClipOval(
          child: Image.file(
            file,
            fit: BoxFit.contain,
            width: 75,
            height: 75,
            errorBuilder: (_, __, ___) =>
                const Icon(Icons.lock, size: 45, color: Colors.black87),
          ),
        );
      }
    }
    return const Icon(Icons.lock, size: 45, color: Colors.black87);
  }

  @override
  Widget build(BuildContext context) {
    String inputLabel = 'ভোটারের নাম লিখুন:';
    TextInputType keyboardType = TextInputType.text;
    List<TextInputFormatter> formatters = [];
    IconData inputIcon = Icons.person_search;

    if (widget.searchMode == 1) {
      inputLabel = 'জন্ম তারিখ (যেমন: ১৫/০৮/১৯৯৫):';
      keyboardType = TextInputType.number;
      formatters = [DateOfBirthMaskFormatter()];
      inputIcon = Icons.calendar_month;
    } else if (widget.searchMode == 2) {
      inputLabel = 'হোল্ডিং নং বা ঠিকানা (যেমন: এ-১৩/৫ বা ০৫):';
      keyboardType = TextInputType.text;
      formatters = [AutoBanglaTextFormatter(isAddress: true)];
      inputIcon = Icons.home_work_outlined;
    } else if (widget.searchMode == 3) {
      inputLabel = 'সিরিয়াল নং লিখুন:';
      keyboardType = TextInputType.number;
      formatters = [AutoBanglaTextFormatter()];
      inputIcon = Icons.format_list_numbered;
    } else if (widget.searchMode == 4) {
      inputLabel = 'ভোটার নাম্বার লিখুন:';
      keyboardType = TextInputType.number;
      formatters = [AutoBanglaTextFormatter()];
      inputIcon = Icons.badge_outlined;
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
            child: Column(
              children: [
                TextField(
                  key: ValueKey('input_field_mode_${widget.searchMode}'),
                  controller: _inputController,
                  focusNode: _focusNode,
                  keyboardType: keyboardType,
                  inputFormatters: formatters,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _executeSearch(),
                  decoration: InputDecoration(
                    labelText: inputLabel,
                    prefixIcon: Icon(inputIcon, color: const Color(0xFF004D40)),
                    border: const UnderlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),

                DropdownButtonFormField<String>(
                  value: _selectedGender,
                  decoration: const InputDecoration(labelText: 'জেন্ডার:'),
                  items: _genders
                      .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedGender = v!),
                ),
                const SizedBox(height: 10),

                DropdownButtonFormField<String>(
                  value: _wards.contains(_selectedWard) ? _selectedWard : 'সকল',
                  decoration: const InputDecoration(
                    labelText: 'ওয়ার্ড বা ইউনিয়ন সিলেক্ট করুন:',
                  ),
                  items: _wards
                      .map((w) => DropdownMenuItem(value: w, child: Text(w)))
                      .toList(),
                  onChanged: _onWardChanged,
                ),
                const SizedBox(height: 10),

                DropdownButtonFormField<String>(
                  value: _areas.contains(_selectedArea) ? _selectedArea : 'সকল',
                  decoration: const InputDecoration(
                    labelText: 'ভোটার এলাকা সিলেক্ট করুন:',
                  ),
                  items: _areas
                      .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedArea = v!),
                ),
                const SizedBox(height: 18),

                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _reset,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE53935),
                        ),
                        child: const Text(
                          'RESET',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _executeSearch,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00695C),
                        ),
                        child: const Text(
                          'SEARCH',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 🔴 নিচে প্রার্থীর ব্যানার ও নির্বাচনী পোস্টার কার্ড সম্পূর্ণরূপে ফিরিয়ে আনা হয়েছে
          if (_candidate != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 15),
              child: Column(
                children: [
                  if (_candidate!.bannerImage != null &&
                      _candidate!.bannerImage!.trim().isNotEmpty)
                    (kIsWeb || _candidate!.bannerImage!.startsWith('http'))
                        ? Image.network(
                            _candidate!.bannerImage!,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const SizedBox.shrink(),
                          )
                        : Image.file(
                            File(_candidate!.bannerImage!),
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const SizedBox.shrink(),
                          ),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 10,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.green.shade800, Colors.teal.shade900],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'আল্লাহ্ সর্বশক্তিমান',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                        Text(
                          '${_candidate!.electionDate}\n${_candidate!.electionTitle}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.shade700,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_candidate!.postTitle}${_candidate!.constituencyOrWard.isNotEmpty ? " (${_candidate!.constituencyOrWard})" : ""}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 75,
                              height: 75,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                                color: Colors.white,
                              ),
                              child: _buildCandidateImage(
                                _candidate!.candidateImage,
                              ),
                            ),
                            const SizedBox(width: 15),
                            Container(
                              width: 75,
                              height: 75,
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: _buildSymbolImage(_candidate!.symbolImage),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${_candidate!.name} -কে',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${_candidate!.symbolName} মার্কায় ভোট দিন',
                          style: const TextStyle(
                            color: Colors.amberAccent,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'দল: ${_candidate!.partyName}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
