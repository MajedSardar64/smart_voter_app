import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:path/path.dart';

import '../models/voter.dart';
import '../utils/bangla_helper.dart';
import '../utils/security_helper.dart';

class DBService {
  static final DBService instance = DBService._init();
  static Database? _database;

  DBService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('voter_data_encrypted_v5.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      password: SecurityHelper.dbSecretKey,
      version: 5,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE voters (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            serialNo TEXT NOT NULL,
            serialInt INTEGER NOT NULL DEFAULT 0,
            voterNo TEXT NOT NULL UNIQUE,
            name TEXT NOT NULL,
            gender TEXT NOT NULL,
            dob TEXT NOT NULL,
            fatherOrHusband TEXT NOT NULL,
            mother TEXT NOT NULL,
            occupation TEXT NOT NULL,
            address TEXT NOT NULL,
            area TEXT NOT NULL,
            union_or_ward_id TEXT,
            union_ward_id TEXT,
            union_or_ward_name TEXT,
            union_ward_name TEXT,
            ward TEXT NOT NULL,
            centerName TEXT NOT NULL,
            centerNo TEXT,
            centerSerial TEXT,
            boothsCount TEXT,
            centerGenderLabel TEXT,
            pollingCenterId INTEGER,
            isMigrated INTEGER NOT NULL,
            publication_date TEXT
          )
        ''');
        await db.execute('CREATE INDEX idx_area ON voters(area)');
        await db.execute('CREATE INDEX idx_ward ON voters(ward)');
        await db.execute('CREATE INDEX idx_name ON voters(name)');
        await db.execute('CREATE INDEX idx_voterNo ON voters(voterNo)');
        await db.execute('CREATE INDEX idx_center ON voters(centerName)');
        await db.execute('CREATE INDEX idx_serialInt ON voters(serialInt)');
        await db.execute('CREATE INDEX idx_gender ON voters(gender)');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          try {
            await db.execute('ALTER TABLE voters ADD COLUMN centerNo TEXT;');
          } catch (_) {}
          try {
            await db.execute(
              'ALTER TABLE voters ADD COLUMN centerSerial TEXT;',
            );
          } catch (_) {}
          try {
            await db.execute('ALTER TABLE voters ADD COLUMN boothsCount TEXT;');
          } catch (_) {}
          try {
            await db.execute(
              'ALTER TABLE voters ADD COLUMN centerGenderLabel TEXT;',
            );
          } catch (_) {}
          try {
            await db.execute(
              'ALTER TABLE voters ADD COLUMN pollingCenterId INTEGER;',
            );
          } catch (_) {}
          try {
            await db.execute('CREATE INDEX idx_center ON voters(centerName);');
          } catch (_) {}
        }
        if (oldVersion < 3) {
          try {
            await db.execute(
              'ALTER TABLE voters ADD COLUMN serialInt INTEGER DEFAULT 0;',
            );
            await db.execute(
              'CREATE INDEX idx_serialInt ON voters(serialInt);',
            );
          } catch (_) {}
        }
        if (oldVersion < 4) {
          try {
            await db.execute('CREATE INDEX idx_gender ON voters(gender);');
          } catch (_) {}
        }
        if (oldVersion < 5) {
          try {
            await db.execute(
              'ALTER TABLE voters ADD COLUMN publication_date TEXT;',
            );
          } catch (_) {}
        }
      },
    );
  }

  Future<int> saveVotersFromApi(List<Voter> voterList) async {
    if (voterList.isEmpty) return 0;
    final db = await instance.database;

    await db.transaction((txn) async {
      var batch = txn.batch();
      for (var v in voterList) {
        int serialInt =
            int.tryParse(
              BanglaHelper.toEnglishDigits(
                v.serialNo.replaceAll(RegExp(r'[^\d০-৯]'), ''),
              ),
            ) ??
            0;

        batch.rawInsert(
          '''
          INSERT OR REPLACE INTO voters (
            serialNo, serialInt, voterNo, name, gender, dob, fatherOrHusband, mother, 
            occupation, address, area, union_or_ward_id, union_ward_id, 
            union_or_ward_name, union_ward_name, ward, centerName, 
            centerNo, centerSerial, boothsCount, centerGenderLabel, 
            pollingCenterId, isMigrated, publication_date
          )
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''',
          [
            v.serialNo,
            serialInt,
            v.voterNo,
            v.name,
            BanglaHelper.formatGender(v.gender),
            v.dob,
            v.fatherOrHusband,
            v.mother,
            v.occupation,
            v.address,
            v.area,
            v.unionOrWardId,
            v.unionWardId,
            v.unionOrWardName,
            v.unionWardName,
            v.ward,
            v.centerName,
            v.centerNo,
            v.centerSerial,
            v.boothsCount,
            BanglaHelper.formatGender(
              v.centerGenderLabel.isNotEmpty ? v.centerGenderLabel : v.gender,
            ),
            v.pollingCenterId,
            v.isMigrated ? 1 : 0,
            v.publicationDate,
          ],
        );
      }
      await batch.commit(noResult: true);
    });

    return voterList.length;
  }

  Future<int> deleteAreaVoters(String areaName) async {
    final db = await instance.database;
    return await db.delete('voters', where: 'area = ?', whereArgs: [areaName]);
  }

  Future<int> deleteMultipleAreas(List<String> areaNames) async {
    if (areaNames.isEmpty) return 0;
    final db = await instance.database;
    final inQuery = List.filled(areaNames.length, '?').join(',');
    return await db.delete(
      'voters',
      where: 'area IN ($inQuery)',
      whereArgs: areaNames,
    );
  }

  Future<void> clearAllVoters() async {
    final db = await instance.database;
    await db.delete('voters');
  }

  Future<List<String>> getDownloadedAreas() async {
    final db = await instance.database;
    final result = await db.rawQuery(
      'SELECT DISTINCT area FROM voters WHERE area != "" ORDER BY area ASC',
    );
    return result.map((e) => e['area'] as String).toList();
  }

  Future<List<String>> getDownloadedWards() async {
    final db = await instance.database;
    final result = await db.rawQuery(
      'SELECT DISTINCT ward FROM voters WHERE ward != "" ORDER BY ward ASC',
    );
    return result.map((e) => e['ward'] as String).toList();
  }

  Future<int> getSearchCount({
    String? name,
    String? dob,
    String? serialNo,
    String? voterNo,
    String? holdingNo,
    String? gender,
    String? ward,
    String? area,
  }) async {
    final db = await instance.database;
    String query = 'SELECT COUNT(*) FROM voters WHERE 1=1';
    List<dynamic> args = [];

    if (name != null && name.trim().isNotEmpty) {
      query += ' AND name LIKE ?';
      args.add('%${name.trim()}%');
    }
    if (voterNo != null && voterNo.trim().isNotEmpty) {
      String bnVoterNo = BanglaHelper.toBanglaDigits(voterNo.trim());
      String enVoterNo = BanglaHelper.toEnglishDigits(voterNo.trim());
      query += ' AND (voterNo LIKE ? OR voterNo LIKE ?)';
      args.addAll(['%$bnVoterNo%', '%$enVoterNo%']);
    }
    if (dob != null && dob.trim().isNotEmpty) {
      final dobVariations = BanglaHelper.generateDobVariations(dob);
      if (dobVariations.isNotEmpty) {
        String dobConditions = dobVariations
            .map((_) => 'dob LIKE ?')
            .join(' OR ');
        query += ' AND ($dobConditions)';
        args.addAll(dobVariations.map((v) => '%$v%'));
      }
    }
    if (serialNo != null && serialNo.trim().isNotEmpty) {
      String bnSerial = BanglaHelper.toBanglaDigits(serialNo.trim());
      String enSerial = BanglaHelper.toEnglishDigits(serialNo.trim());
      query += ' AND (serialNo = ? OR serialNo = ?)';
      args.addAll([bnSerial, enSerial]);
    }
    if (holdingNo != null && holdingNo.trim().isNotEmpty) {
      String clean = holdingNo.trim();
      String bn = BanglaHelper.toBanglaDigits(clean);
      String en = BanglaHelper.toEnglishDigits(clean);
      query += ' AND (address LIKE ? OR address LIKE ?)';
      args.addAll(['%$bn%', '%$en%']);
    }
    if (gender != null && gender != 'সকল') {
      query += ' AND gender = ?';
      args.add(gender);
    }
    if (ward != null && ward != 'সকল') {
      query += ' AND ward = ?';
      args.add(ward);
    }
    if (area != null && area != 'সকল') {
      query += ' AND area = ?';
      args.add(area);
    }

    return Sqflite.firstIntValue(await db.rawQuery(query, args)) ?? 0;
  }

  Future<List<Voter>> searchVotersPaginated({
    String? name,
    String? dob,
    String? serialNo,
    String? voterNo,
    String? holdingNo,
    String? gender,
    String? ward,
    String? area,
    int limit = 200,
    int offset = 0,
  }) async {
    final db = await instance.database;
    String query = 'SELECT * FROM voters WHERE 1=1';
    List<dynamic> args = [];

    if (name != null && name.trim().isNotEmpty) {
      query += ' AND name LIKE ?';
      args.add('%${name.trim()}%');
    }
    if (voterNo != null && voterNo.trim().isNotEmpty) {
      String bnVoterNo = BanglaHelper.toBanglaDigits(voterNo.trim());
      String enVoterNo = BanglaHelper.toEnglishDigits(voterNo.trim());
      query += ' AND (voterNo LIKE ? OR voterNo LIKE ?)';
      args.addAll(['%$bnVoterNo%', '%$enVoterNo%']);
    }
    if (dob != null && dob.trim().isNotEmpty) {
      final dobVariations = BanglaHelper.generateDobVariations(dob);
      if (dobVariations.isNotEmpty) {
        String dobConditions = dobVariations
            .map((_) => 'dob LIKE ?')
            .join(' OR ');
        query += ' AND ($dobConditions)';
        args.addAll(dobVariations.map((v) => '%$v%'));
      }
    }
    if (serialNo != null && serialNo.trim().isNotEmpty) {
      String bnSerial = BanglaHelper.toBanglaDigits(serialNo.trim());
      String enSerial = BanglaHelper.toEnglishDigits(serialNo.trim());
      query += ' AND (serialNo = ? OR serialNo = ?)';
      args.addAll([bnSerial, enSerial]);
    }
    if (holdingNo != null && holdingNo.trim().isNotEmpty) {
      String clean = holdingNo.trim();
      String bn = BanglaHelper.toBanglaDigits(clean);
      String en = BanglaHelper.toEnglishDigits(clean);
      query += ' AND (address LIKE ? OR address LIKE ?)';
      args.addAll(['%$bn%', '%$en%']);
    }
    if (gender != null && gender != 'সকল') {
      query += ' AND gender = ?';
      args.add(gender);
    }
    if (ward != null && ward != 'সকল') {
      query += ' AND ward = ?';
      args.add(ward);
    }
    if (area != null && area != 'সকল') {
      query += ' AND area = ?';
      args.add(area);
    }

    query += ' ORDER BY serialInt ASC, id ASC LIMIT ? OFFSET ?';
    args.addAll([limit, offset]);

    final result = await db.rawQuery(query, args);
    return result.map((json) => Voter.fromMap(json)).toList();
  }

  Future<List<Voter>> searchByNidOrOCR({
    String? dob,
    String? banglaName,
    String? father,
    String? mother,
    String? englishName,
    String? nid,
  }) async {
    final db = await instance.database;
    String query = 'SELECT * FROM voters WHERE 1=0';
    List<dynamic> args = [];

    if (dob != null && dob.trim().isNotEmpty) {
      final dobVariations = BanglaHelper.generateDobVariations(dob);
      for (var v in dobVariations) {
        query += ' OR dob LIKE ?';
        args.add('%$v%');
      }
    }
    if (banglaName != null && banglaName.trim().isNotEmpty) {
      query += ' OR name LIKE ?';
      args.add('%${banglaName.trim()}%');
    }
    if (father != null && father.trim().isNotEmpty) {
      query += ' OR fatherOrHusband LIKE ?';
      args.add('%${father.trim()}%');
    }
    if (mother != null && mother.trim().isNotEmpty) {
      query += ' OR mother LIKE ?';
      args.add('%${mother.trim()}%');
    }
    if (englishName != null && englishName.trim().isNotEmpty) {
      query += ' OR name LIKE ?';
      args.add('%${englishName.trim()}%');
    }
    if (nid != null && nid.trim().isNotEmpty) {
      String cleanNid = nid.replaceAll(' ', '').trim();
      query += ' OR voterNo LIKE ? OR voterNo LIKE ?';
      args.addAll([
        '%$cleanNid%',
        '%${BanglaHelper.toBanglaDigits(cleanNid)}%',
      ]);
    }

    query += ''' ORDER BY 
      (CASE WHEN dob LIKE ? THEN 8 ELSE 0 END) +
      (CASE WHEN name LIKE ? THEN 6 ELSE 0 END) +
      (CASE WHEN fatherOrHusband LIKE ? THEN 4 ELSE 0 END) +
      (CASE WHEN voterNo LIKE ? THEN 2 ELSE 0 END) DESC LIMIT 20''';

    args.add(dob != null && dob.isNotEmpty ? '%${dob.trim()}%' : '');
    args.add(
      banglaName != null && banglaName.isNotEmpty
          ? '%${banglaName.trim()}%'
          : '',
    );
    args.add(father != null && father.isNotEmpty ? '%${father.trim()}%' : '');
    args.add(
      nid != null && nid.isNotEmpty
          ? '%${nid.replaceAll(' ', '').trim()}%'
          : '',
    );

    final result = await db.rawQuery(query, args);
    return result.map((json) => Voter.fromMap(json)).toList();
  }

  // 🔴 শতভাগ নিখুঁত ফ্যামিলি সার্চ (হোল্ডিং ম্যাচ + বড় শব্দের অগ্রাধিকার)
  Future<List<Voter>> searchFamily(Voter voter) async {
    final db = await instance.database;

    // ১. বাংলা নামের সব বৈচিত্র্য স্বাভাবিকীকরণ
    String normalizeBanglaSpelling(String text) {
      String t = text.trim();
      if (t.isEmpty || t == 'প্রযোজ্য নয়' || t == 'মৃত') return '';

      return t
          .replaceAll('আবদুল্লাহ', 'আব্দুল্লাহ')
          .replaceAll('আবদুল', 'আব্দুল')
          .replaceAll('আঃ', 'আব্দুল')
          .replaceAll('মোহাম্মদ', 'মোঃ')
          .replaceAll('মুহাম্মদ', 'মোঃ')
          .replaceAll('মোহাঃ', 'মোঃ')
          .replaceAll('মোসাঃ', 'মোসাম্মৎ')
          .replaceAll('মোসা:', 'মোসাম্মৎ')
          .replaceAll('মোসা.', 'মোসাম্মৎ')
          .replaceAll('মো:', 'মোঃ')
          .replaceAll('মো.', 'মোঃ')
          .replaceAll('মিঃ', 'মি.')
          .replaceAll('এমডি', 'মোঃ')
          .replaceAll('MD', 'মোঃ')
          .replaceAll('Md.', 'মোঃ');
    }

    // ২. স্মার্ট কোর নেম ডিটেকশন
    String extractSmartCoreName(String raw) {
      String norm = normalizeBanglaSpelling(raw);
      if (norm.isEmpty) return '';

      final prefixes = RegExp(
        r'^(মোঃ|মোসাম্মৎ|মৃত|মি\.|শেখ|সৈয়দ|কাজী|মিসেস|ডাঃ)\s+',
        caseSensitive: false,
      );
      String withoutPrefix = norm.replaceAll(prefixes, '').trim();

      final suffixes = RegExp(
        r'\s+(বেগম|খাতুন|বিবি|বানু|মিয়া|আলী|চৌধুরী|খান|হোসেন|হাসান|আহমেদ|রহমান|হক|শিকদার|মোল্লা|সরকার)$',
        caseSensitive: false,
      );
      String withoutSuffix = withoutPrefix.replaceAll(suffixes, '').trim();

      if (withoutSuffix.length < 3) {
        return withoutPrefix.isNotEmpty ? withoutPrefix : norm;
      }
      return withoutSuffix;
    }

    // ৩. 🔴 বড় শব্দকে আগে প্রাধান্য দিয়ে টোকেনাইজেশন (দৈর্ঘ্যের ক্রমানুসারে সর্ট)
    List<String> getMeaningfulTokensSortedByLength(String raw) {
      String norm = normalizeBanglaSpelling(raw);
      final words = norm
          .split(RegExp(r'[\s\.\-]+'))
          .map((w) => w.trim())
          .where((w) => w.length >= 3 && w != 'মোঃ' && w != 'মোসাম্মৎ')
          .toSet()
          .toList();

      // বড় শব্দগুলোকে সবার আগে আনা
      words.sort((a, b) => b.length.compareTo(a.length));
      return words;
    }

    // ৪. 🔴 ঠিকানা থেকে হোল্ডিং/বাসা নম্বর সঠিকভাবে বের করার হেল্পার
    String extractHoldingNumber(String address) {
      String addr = address.trim();
      if (addr.isEmpty) return '';

      final match = RegExp(
        r'(?:হোল্ডিং|বাসা|রোড|বাড়ি|বাড়ি|House|Holding|Road)[\s\:\-\/№#]*([A-Za-z০-৯0-9\/\-]+)',
        caseSensitive: false,
      ).firstMatch(addr);

      if (match != null) {
        return BanglaHelper.toBanglaDigits(match.group(1)!.trim());
      }

      final startMatch = RegExp(r'^([A-Za-z\u0980-\u09FF০-৯0-9\/\-]+)')
          .firstMatch(addr);
      if (startMatch != null) {
        String token = startMatch.group(1)!.trim();
        if (RegExp(r'[০-৯0-9]').hasMatch(token) && token.length <= 12) {
          return BanglaHelper.toBanglaDigits(token);
        }
      }
      return '';
    }

    final String coreFather = extractSmartCoreName(voter.fatherOrHusband);
    final String coreMother = extractSmartCoreName(voter.mother);
    final String coreSelf = extractSmartCoreName(voter.name);
    final String gender = BanglaHelper.formatGender(voter.gender);
    final String voterHolding = extractHoldingNumber(voter.address);

    final List<String> fTokens = getMeaningfulTokensSortedByLength(
      voter.fatherOrHusband,
    );
    final List<String> mTokens = getMeaningfulTokensSortedByLength(
      voter.mother,
    );
    final List<String> sTokens = getMeaningfulTokensSortedByLength(voter.name);

    List<String> conditions = [];
    List<dynamic> args = [];

    // ক. পিতা ও মাতার মূল নাম সম্পূর্ণ মিল
    if (coreFather.isNotEmpty && coreMother.isNotEmpty) {
      conditions.add('(fatherOrHusband LIKE ? AND mother LIKE ?)');
      args.addAll(['%$coreFather%', '%$coreMother%']);

      // বড় শব্দগুলোকে আগে মিলিয়ে পেয়ার ম্যাচিং
      for (var ft in fTokens) {
        for (var mt in mTokens) {
          conditions.add('(fatherOrHusband LIKE ? AND mother LIKE ?)');
          args.addAll(['%$ft%', '%$mt%']);
        }
      }
    }

    // খ. নিজের নাম অন্যের পিতা অথবা মাতা হিসেবে
    if (coreSelf.isNotEmpty) {
      conditions.add('(fatherOrHusband LIKE ?)');
      args.add('%$coreSelf%');
      conditions.add('(mother LIKE ?)');
      args.add('%$coreSelf%');
    }

    // গ. পিতার মূল নাম সম্পূর্ণ মিল
    if (coreFather.isNotEmpty) {
      conditions.add('(fatherOrHusband LIKE ?)');
      args.add('%$coreFather%');
    }

    // ঘ. মাতার মূল নাম সম্পূর্ণ মিল
    if (coreMother.isNotEmpty) {
      conditions.add('(mother LIKE ?)');
      args.add('%$coreMother%');
    }

    // ঙ. হোল্ডিং নম্বর ও একই এলাকা ম্যাচিং (অন্য এলাকার একই হোল্ডিং যেন না আসে)
    if (voterHolding.isNotEmpty && voter.area.isNotEmpty) {
      conditions.add('(address LIKE ? AND area = ?)');
      args.addAll(['%$voterHolding%', voter.area]);
    }

    if (conditions.isEmpty) return [];

    final String orWhere = conditions.join(' OR ');

    // 🔴 SQL লেভেলেই পিতা+মাতা এবং বড় শব্দকে সর্বোচ্চ স্কোর দিয়ে আনা
    final String sql =
        '''
      SELECT * FROM voters 
      WHERE id != ? AND voterNo != ? AND ($orWhere)
      ORDER BY 
        (CASE WHEN (fatherOrHusband LIKE ? AND mother LIKE ?) THEN 100 ELSE 0 END) +
        (CASE WHEN (address LIKE ? AND area = ?) THEN 45 ELSE 0 END) +
        (CASE WHEN (fatherOrHusband LIKE ? OR mother LIKE ?) THEN 35 ELSE 0 END) DESC,
        id ASC
      LIMIT 80
    ''';

    final List<dynamic> queryParams = [
      voter.id,
      voter.voterNo,
      ...args,
      '%$coreFather%',
      '%$coreMother%',
      voterHolding.isNotEmpty ? '%$voterHolding%' : '',
      voter.area,
      '%$coreFather%',
      '%$coreMother%',
    ];

    final result = await db.rawQuery(sql, queryParams);
    List<Map<String, dynamic>> scoredList = [];

    for (var row in result) {
      final v = Voter.fromMap(row);
      final rFather = extractSmartCoreName(v.fatherOrHusband);
      final rMother = extractSmartCoreName(v.mother);
      final rName = extractSmartCoreName(v.name);

      final List<String> rFTokens = getMeaningfulTokensSortedByLength(
        v.fatherOrHusband,
      );
      final List<String> rMTokens = getMeaningfulTokensSortedByLength(v.mother);
      final List<String> rSTokens = getMeaningfulTokensSortedByLength(v.name);

      // 🔴 হোল্ডিং নম্বর ম্যাচ নিশ্চিত করা (শুধুমাত্র একই এলাকা হলেই সত্য হবে)
      final bool isSameArea = (v.area.trim() == voter.area.trim());
      final String rHolding = extractHoldingNumber(v.address);
      final bool isSameHoldingAndArea =
          isSameArea &&
          voterHolding.isNotEmpty &&
          rHolding.isNotEmpty &&
          (voterHolding == rHolding);

      int score = 0;
      String relation = '';

      final bool fMatchExact =
          coreFather.isNotEmpty &&
          (rFather.contains(coreFather) || coreFather.contains(rFather));
      final bool mMatchExact =
          coreMother.isNotEmpty &&
          (rMother.contains(coreMother) || coreMother.contains(rMother));

      // ১. সহোদর ভাই/বোন (পিতা ও মাতা উভয়ের মিল): ১০০%
      if (fMatchExact && mMatchExact) {
        score = 100;
        relation = isSameHoldingAndArea
            ? '১০০% মিল (একই বাসার সহোদর)'
            : (isSameArea
                  ? '১০০% মিল (সহোদর ভাই/বোন)'
                  : '১০০% মিল (অন্য এলাকায় সহোদর)');
      }
      // ২. পিতা ও মাতার শব্দ ম্যাচ (বড় শব্দ আগে বিবেচনায় নিয়ে): ৯০% - ৯৫%
      else if (fTokens.any((t) => rFTokens.contains(t)) &&
          mTokens.any((t) => rMTokens.contains(t))) {
        score = isSameHoldingAndArea ? 95 : 90;
        relation = isSameHoldingAndArea
            ? '৯৫% মিল (একই বাসা ও পিতা-মাতা)'
            : '৯০% মিল (পিতা ও মাতার নাম)';
      }
      // ৩. স্বামী বা স্ত্রী ম্যাচ: ৮৫% - ৯০%
      else if (gender == 'পুরুষ' &&
          (rFather == coreSelf || rFTokens.any((t) => sTokens.contains(t))) &&
          isSameArea) {
        score = isSameHoldingAndArea ? 95 : 90;
        relation = isSameHoldingAndArea
            ? '৯৫% মিল (স্ত্রী - একই বাসা)'
            : '৯০% মিল (স্ত্রী/সন্তান)';
      } else if (gender == 'মহিলা' &&
          (voter.fatherOrHusband.contains(rName) ||
              sTokens.any((t) => rSTokens.contains(t))) &&
          isSameArea) {
        score = isSameHoldingAndArea ? 95 : 90;
        relation = isSameHoldingAndArea
            ? '৯৫% মিল (স্বামী - একই বাসা)'
            : '৯০% মিল (স্বামী)';
      }
      // ৪. সন্তান ম্যাচ: ৮০% - ৮৫%
      else if (coreSelf.isNotEmpty &&
          (rFather == coreSelf || rMother == coreSelf)) {
        score = isSameHoldingAndArea ? 85 : 80;
        relation = isSameHoldingAndArea
            ? '৮৫% মিল (সন্তান - একই বাসা)'
            : '৮০% মিল (সন্তান)';
      }
      // ৫. পিতা মিল + একই বাসা/হোল্ডিং এবং এরিয়া: ৮০%
      else if (fMatchExact && isSameHoldingAndArea) {
        score = 80;
        relation = '৮০% মিল (পিতা ও একই বাসা)';
      }
      // ৬. পিতা মিল + একই এলাকা: ৭৫%
      else if (fMatchExact && isSameArea) {
        score = 75;
        relation = '৭৫% মিল (পিতা ও এলাকা)';
      }
      // ৭. মাতা মিল + একই বাসা/হোল্ডিং: ৭৫%
      else if (mMatchExact && isSameHoldingAndArea) {
        score = 75;
        relation = '৭৫% মিল (মাতা ও একই বাসা)';
      }
      // ৮. মাতা মিল + একই এলাকা: ৭০%
      else if (mMatchExact && isSameArea) {
        score = 70;
        relation = '৭০% মিল (মাতা ও এলাকা)';
      }
      // ৯. ভিন্ন এলাকায় পিতার সম্পূর্ণ মিল: ৬০%
      else if (fMatchExact) {
        score = 60;
        relation = '৬০% মিল (পিতার নাম মিল)';
      }
      // ১০. বড় শব্দ (Length >= 5) মিললে ৬০%, ছোট শব্দ মিললে ৫০%
      else {
        String? matchedWord;
        for (var ft in fTokens) {
          if (rFTokens.contains(ft)) {
            matchedWord = ft;
            break;
          }
        }
        if (matchedWord == null) {
          for (var mt in mTokens) {
            if (rMTokens.contains(mt)) {
              matchedWord = mt;
              break;
            }
          }
        }

        if (matchedWord != null) {
          if (matchedWord.length >= 5) {
            score = isSameArea ? 65 : 60;
            relation = '$score% মিল (${matchedWord} - মূল নাম)';
          } else {
            score = 50;
            relation = '৫০% মিল (${matchedWord})';
          }
        }
      }

      // 🔴 ৫০% বা তার বেশি মিললেই ফলাফলে যুক্ত হবে
      if (score >= 50) {
        final voterMap = v.toMap();
        voterMap['match_percent'] = score;
        voterMap['relation_tag'] = relation;
        scoredList.add(voterMap);
      }
    }

    // সর্বোচ্চ মিল (১০০%, ৯৫%, ৯০%, ৮৫%, ৮০%, ৭৫%, ৭০%, ৬৫%, ৬০%, ৫০%) ক্রমানুসারে সাজানো
    scoredList.sort(
      (a, b) =>
          (b['match_percent'] as int).compareTo(a['match_percent'] as int),
    );

    return scoredList.map((m) => Voter.fromMap(m)).toList();
  }

  Future<Map<String, dynamic>> getDashboardStats() async {
    final db = await instance.database;

    final totalVoters =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM voters'),
        ) ??
        0;

    final totalCenters =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(DISTINCT centerName) FROM voters WHERE centerName != "" AND centerName != "অনির্ধারিত কেন্দ্র"',
          ),
        ) ??
        0;

    final totalAreas =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(DISTINCT area) FROM voters WHERE area != ""',
          ),
        ) ??
        0;

    final pubResult = await db.rawQuery(
      'SELECT DISTINCT publication_date FROM voters WHERE publication_date != "" AND publication_date IS NOT NULL',
    );
    final List<String> publicationDates = pubResult
        .map((e) => e['publication_date']?.toString() ?? '')
        .where((s) => s.isNotEmpty)
        .toList();

    final areaBreakdown = await db.rawQuery('''
      SELECT area,
             SUM(CASE WHEN gender = 'পুরুষ' THEN 1 ELSE 0 END) as maleCount,
             SUM(CASE WHEN gender = 'মহিলা' THEN 1 ELSE 0 END) as femaleCount,
             SUM(CASE WHEN gender = 'হিজড়া' THEN 1 ELSE 0 END) as hijraCount,
             COUNT(*) as total
      FROM voters
      WHERE area != ""
      GROUP BY area
      ORDER BY area ASC
    ''');

    final centerBreakdownRaw = await db.rawQuery('''
      SELECT COALESCE(NULLIF(centerName, ''), 'অনির্ধারিত কেন্দ্র') as center,
             COALESCE(centerNo, '') as centerNo,
             COALESCE(centerSerial, '') as centerSerial,
             COALESCE(boothsCount, '') as boothsCount,
             area,
             gender,
             MIN(serialInt) as startSerial,
             MAX(serialInt) as endSerial,
             COUNT(*) as totalCount
      FROM voters
      WHERE area != ""
      GROUP BY centerName, centerNo, centerSerial, boothsCount, area, gender
      ORDER BY CAST(centerSerial AS INTEGER) ASC, center ASC, area ASC,
               CASE WHEN gender = 'পুরুষ' THEN 1 WHEN gender = 'মহিলা' THEN 2 ELSE 3 END
    ''');

    int totalMigratedVoters = 0;
    List<Map<String, dynamic>> centerBreakdown = [];

    for (var row in centerBreakdownRaw) {
      int start = int.tryParse(row['startSerial']?.toString() ?? '0') ?? 0;
      int end = int.tryParse(row['endSerial']?.toString() ?? '0') ?? 0;
      int count = int.tryParse(row['totalCount']?.toString() ?? '0') ?? 0;
      int expected = (start > 0 && end >= start) ? (end - start + 1) : count;
      int migrated = (expected > count) ? (expected - count) : 0;
      totalMigratedVoters += migrated;

      Map<String, dynamic> mutableRow = Map<String, dynamic>.from(row);
      mutableRow['migratedCount'] = migrated;
      centerBreakdown.add(mutableRow);
    }

    return {
      'totalVoters': totalVoters,
      'migratedVoters': totalMigratedVoters,
      'totalCenters': totalCenters,
      'totalAreas': totalAreas,
      'publicationDates': publicationDates,
      'areaBreakdown': areaBreakdown,
      'centerBreakdown': centerBreakdown,
    };
  }
}
