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
    _database = await _initDB('voter_data_encrypted_v4.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      password: SecurityHelper.dbSecretKey,
      version: 4,
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
            isMigrated INTEGER NOT NULL
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
          try {
            await db.rawUpdate('''
              UPDATE voters 
              SET serialInt = CAST(
                REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
                  serialNo, '০','0'), '১','1'), '২','2'), '৩','3'), '৪','4'), '৫','5'), '৬','6'), '৭','7'), '৮','8'), '৯','9'
                ) AS INTEGER
              )
              WHERE serialInt = 0 OR serialInt IS NULL;
            ''');
          } catch (_) {}
        }
      },
    );
  }

  // 🔴 যদি প্যানেল থেকে কেন্দ্র বন্ধ করা হয়, অফলাইন ডেটাবেজের কেন্দ্র মুছে দেওয়া
  Future<void> clearAllPollingCenters() async {
    final db = await instance.database;
    await db.rawUpdate('''
      UPDATE voters 
      SET centerName = '', centerNo = '', centerSerial = '', boothsCount = '', pollingCenterId = 0
    ''');
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
            pollingCenterId, isMigrated
          )
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
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

  Future<List<String>> getAvailableAreas({String? ward}) async {
    final db = await instance.database;
    String query = 'SELECT DISTINCT area FROM voters WHERE area != ""';
    List<dynamic> args = [];

    if (ward != null && ward != 'সকল') {
      query += ' AND ward = ?';
      args.add(ward);
    }
    query += ' ORDER BY area ASC';

    final result = await db.rawQuery(query, args);
    List<String> areas = result.map((e) => e['area'] as String).toList();
    return ['সকল', ...areas];
  }

  Future<List<String>> getAvailableWards() async {
    final db = await instance.database;
    final result = await db.rawQuery(
      'SELECT DISTINCT ward FROM voters WHERE ward != "" ORDER BY ward ASC',
    );
    List<String> wards = result.map((e) => e['ward'] as String).toList();
    return ['সকল', ...wards];
  }

  Future<List<String>> getAvailableGenders({String? area, String? ward}) async {
    return ['সকল', 'পুরুষ', 'মহিলা', 'হিজড়া'];
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

  Future<List<Voter>> searchFamily(Voter voter) async {
    final db = await instance.database;

    String extractCoreName(String name) {
      String n = name.trim();
      if (n.isEmpty || n == 'প্রযোজ্য নয়' || n == 'মৃত') return '';
      final prefixes = RegExp(
        r'^(মোঃ|মো:|মো\.|মোসাঃ|মোসা:|মোসা\.|মুহাম্মদ|মোহাম্মদ|মৃত|আঃ|আ:|আ\.|মিঃ|মি:|মি\.|শেখ|সৈয়দ|কাজী|এমডি|MD|MST|মিসেস|ডাঃ)\s+',
        caseSensitive: false,
      );
      String cleaned = n.replaceAll(prefixes, '');
      final suffixes = RegExp(
        r'\s+(বেগম|খাতুন|বিবি|বানু|মিয়া|আলী|চৌধুরী|খান|হোসেন|হাসান|আহমেদ|রহমান|হক|শিকদার|মোল্লা|সরকার)$',
        caseSensitive: false,
      );
      return cleaned.replaceAll(suffixes, '').trim();
    }

    final String coreFather = extractCoreName(voter.fatherOrHusband);
    final String coreMother = extractCoreName(voter.mother);
    final String coreSelf = extractCoreName(voter.name);
    final String gender = BanglaHelper.formatGender(voter.gender);

    List<String> conditions = [];
    List<dynamic> args = [];

    if (coreFather.isNotEmpty && coreMother.isNotEmpty) {
      conditions.add('(fatherOrHusband LIKE ? AND mother LIKE ?)');
      args.addAll(['%$coreFather%', '%$coreMother%']);

      final fWords = coreFather.split(' ').where((w) => w.length >= 3);
      final mWords = coreMother.split(' ').where((w) => w.length >= 3);
      for (var fw in fWords) {
        for (var mw in mWords) {
          conditions.add('(fatherOrHusband LIKE ? AND mother LIKE ?)');
          args.addAll(['%$fw%', '%$mw%']);
        }
      }
    }

    if (coreSelf.isNotEmpty) {
      if (gender == 'মহিলা') {
        conditions.add('(mother LIKE ?)');
        args.add('%$coreSelf%');
      } else {
        conditions.add('(fatherOrHusband LIKE ?)');
        args.add('%$coreSelf%');
      }
    }

    if (conditions.isEmpty) return [];

    final String orWhere = conditions.join(' OR ');
    final String sql =
        '''
      SELECT * FROM voters 
      WHERE id != ? AND voterNo != ? AND ($orWhere)
      ORDER BY 
        (CASE WHEN (fatherOrHusband LIKE ? AND mother LIKE ?) THEN 40 ELSE 0 END) +
        (CASE WHEN (fatherOrHusband LIKE ? OR mother LIKE ?) THEN 25 ELSE 0 END) DESC
      LIMIT 50
    ''';

    final List<dynamic> queryParams = [
      voter.id,
      voter.voterNo,
      ...args,
      '%$coreFather%',
      '%$coreMother%',
      '%$coreSelf%',
      '%$coreSelf%',
    ];

    final result = await db.rawQuery(sql, queryParams);
    return result.map((json) => Voter.fromMap(json)).toList();
  }

  Future<Map<String, dynamic>> getDashboardStats() async {
    final db = await instance.database;

    try {
      await db.rawUpdate('''
        UPDATE voters 
        SET serialInt = CAST(
          REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
            serialNo, '০','0'), '১','1'), '২','2'), '৩','3'), '৪','4'), '৫','5'), '৬','6'), '৭','7'), '৮','8'), '৯','9'
          ) AS INTEGER
        )
        WHERE serialInt = 0 OR serialInt IS NULL;
      ''');
    } catch (_) {}

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
      'areaBreakdown': areaBreakdown,
      'centerBreakdown': centerBreakdown,
    };
  }
}
