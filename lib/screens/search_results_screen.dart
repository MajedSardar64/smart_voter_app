import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/candidate.dart';
import '../models/voter.dart';
import '../services/api_service.dart';
import '../services/db_service.dart';
import '../utils/bangla_helper.dart';
import 'voter_detail_screen.dart';

class SearchResultsScreen extends StatefulWidget {
  final String filterText;
  final String? name;
  final String? dob;
  final String? serialNo;
  final String? voterNo;
  final String? holdingNo;
  final String? gender;
  final String? ward;
  final String? area;
  final List<Voter>? directResults;

  const SearchResultsScreen({
    super.key,
    required this.filterText,
    this.name,
    this.dob,
    this.serialNo,
    this.voterNo,
    this.holdingNo,
    this.gender,
    this.ward,
    this.area,
    this.directResults,
  });

  @override
  State<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  final List<Voter> _voters = [];
  final ScrollController _scrollController = ScrollController();
  Candidate? _candidate;

  int _totalCount = 0;
  int _offset = 0;
  final int _limit = 200;
  bool _isLoadingInitial = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusManager.instance.primaryFocus?.unfocus();
    });

    _loadCandidateAndInit();
  }

  void _loadCandidateAndInit() async {
    final cand = await AuthService.getActiveCandidate();
    if (mounted) setState(() => _candidate = cand);

    if (widget.directResults != null) {
      _voters.addAll(widget.directResults!);
      _totalCount = widget.directResults!.length;
      _isLoadingInitial = false;
      _hasMore = false;
    } else {
      _initLoad();
      _scrollController.addListener(_onScroll);
    }
  }

  void _initLoad() async {
    setState(() => _isLoadingInitial = true);

    if (kIsWeb) {
      String searchType = 'name';
      String keyword = '';

      if (widget.name != null && widget.name!.isNotEmpty) {
        searchType = 'name';
        keyword = widget.name!;
      } else if (widget.dob != null && widget.dob!.isNotEmpty) {
        searchType = 'dob';
        keyword = widget.dob!;
      } else if (widget.voterNo != null && widget.voterNo!.isNotEmpty) {
        searchType = 'voter_no';
        keyword = widget.voterNo!;
      } else if (widget.serialNo != null && widget.serialNo!.isNotEmpty) {
        searchType = 'serial_no';
        keyword = widget.serialNo!;
      } else if (widget.holdingNo != null && widget.holdingNo!.isNotEmpty) {
        searchType = 'address';
        keyword = widget.holdingNo!;
      }

      final result = await VoterApiService.searchVotersOnline(
        searchType: searchType,
        keyword: keyword,
        ward: widget.ward,
        area: widget.area,
        gender: widget.gender,
        limit: _limit,
        offset: 0,
      );

      final List<Voter> onlineVoters = result['voters'] ?? [];
      final int count = result['count'] ?? onlineVoters.length;

      if (!mounted) return;
      setState(() {
        _totalCount = count;
        _voters.addAll(onlineVoters);
        _offset = onlineVoters.length;
        _hasMore = _voters.length < _totalCount;
        _isLoadingInitial = false;
      });
      return;
    }

    final count = await DBService.instance.getSearchCount(
      name: widget.name,
      dob: widget.dob,
      serialNo: widget.serialNo,
      voterNo: widget.voterNo,
      holdingNo: widget.holdingNo,
      gender: widget.gender,
      ward: widget.ward,
      area: widget.area,
    );

    final firstBatch = await DBService.instance.searchVotersPaginated(
      name: widget.name,
      dob: widget.dob,
      serialNo: widget.serialNo,
      voterNo: widget.voterNo,
      holdingNo: widget.holdingNo,
      gender: widget.gender,
      ward: widget.ward,
      area: widget.area,
      limit: _limit,
      offset: 0,
    );

    if (!mounted) return;
    setState(() {
      _totalCount = count;
      _voters.addAll(firstBatch);
      _offset = firstBatch.length;
      _hasMore = _voters.length < _totalCount;
      _isLoadingInitial = false;
    });
  }

  void _onScroll() async {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 350 &&
        !_isLoadingMore &&
        _hasMore) {
      setState(() => _isLoadingMore = true);

      if (kIsWeb) {
        String searchType = 'name';
        String keyword = '';

        if (widget.name != null && widget.name!.isNotEmpty) {
          searchType = 'name';
          keyword = widget.name!;
        } else if (widget.dob != null && widget.dob!.isNotEmpty) {
          searchType = 'dob';
          keyword = widget.dob!;
        } else if (widget.voterNo != null && widget.voterNo!.isNotEmpty) {
          searchType = 'voter_no';
          keyword = widget.voterNo!;
        } else if (widget.serialNo != null && widget.serialNo!.isNotEmpty) {
          searchType = 'serial_no';
          keyword = widget.serialNo!;
        } else if (widget.holdingNo != null && widget.holdingNo!.isNotEmpty) {
          searchType = 'address';
          keyword = widget.holdingNo!;
        }

        final result = await VoterApiService.searchVotersOnline(
          searchType: searchType,
          keyword: keyword,
          ward: widget.ward,
          area: widget.area,
          gender: widget.gender,
          limit: _limit,
          offset: _offset,
        );

        final List<Voter> nextBatch = result['voters'] ?? [];

        if (!mounted) return;
        setState(() {
          _voters.addAll(nextBatch);
          _offset += nextBatch.length;
          _hasMore = _voters.length < _totalCount;
          _isLoadingMore = false;
        });
        return;
      }

      final nextBatch = await DBService.instance.searchVotersPaginated(
        name: widget.name,
        dob: widget.dob,
        serialNo: widget.serialNo,
        voterNo: widget.voterNo,
        holdingNo: widget.holdingNo,
        gender: widget.gender,
        ward: widget.ward,
        area: widget.area,
        limit: _limit,
        offset: _offset,
      );

      if (!mounted) return;
      setState(() {
        _voters.addAll(nextBatch);
        _offset += nextBatch.length;
        _hasMore = _voters.length < _totalCount;
        _isLoadingMore = false;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String banglaTotal = BanglaHelper.toBanglaDigits(_totalCount.toString());
    String banglaCurrent = BanglaHelper.toBanglaDigits(
      _voters.length.toString(),
    );

    final bool canShowCenter = _candidate?.showPollingCenter != false;

    return Scaffold(
      appBar: AppBar(title: const Text('ভোটার অনুসন্ধান ফলাফল')),
      body: _isLoadingInitial
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00695C)),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  color: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFF1F5F9),
                  child: Text(
                    'Showing $banglaCurrent of $banglaTotal. Filter: ${widget.filterText}',
                    style: TextStyle(
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF334155),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Divider(height: 1),

                Expanded(
                  child: _voters.isEmpty
                      ? const Center(
                          child: Text(
                            'কোন ভোটারের তথ্য পাওয়া যায়নি!',
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.black54,
                            ),
                          ),
                        )
                      : ListView.separated(
                          controller: _scrollController,
                          itemCount: _voters.length + (_hasMore ? 1 : 0),
                          separatorBuilder: (_, __) => Divider(
                            height: 1,
                            color: isDark
                                ? Colors.white12
                                : const Color(0xFFE2E8F0),
                          ),
                          itemBuilder: (ctx, index) {
                            if (index == _voters.length) {
                              return const Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: Color(0xFF00695C),
                                    strokeWidth: 2,
                                  ),
                                ),
                              );
                            }

                            final voter = _voters[index];
                            final bool showThisCenter =
                                canShowCenter &&
                                voter.centerName.isNotEmpty &&
                                voter.centerName != 'অনির্ধারিত কেন্দ্র';

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              title: Text(
                                voter.name,
                                style: const TextStyle(
                                  color: Color(0xFF2563EB),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 3),
                                  Text(
                                    'পিতা/স্বামী: ${voter.fatherOrHusband}',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      color: isDark
                                          ? Colors.white70
                                          : const Color(0xFF334155),
                                    ),
                                  ),
                                  if (voter.mother.isNotEmpty)
                                    Text(
                                      'মাতা: ${voter.mother}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isDark
                                            ? Colors.white60
                                            : const Color(0xFF475569),
                                      ),
                                    ),
                                  if (showThisCenter) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      voter.centerName,
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        color: Color(0xFF0D9488),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              trailing: const Icon(
                                Icons.arrow_forward_ios,
                                size: 14,
                                color: Colors.grey,
                              ),
                              onTap: () {
                                FocusManager.instance.primaryFocus?.unfocus();
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        VoterDetailScreen(voter: voter),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
