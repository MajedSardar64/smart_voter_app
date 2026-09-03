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
    _database = await _initDB('voter_data_encrypted_v1.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      password: SecurityHelper.dbSecretKey,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE voters (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            serialNo TEXT NOT NULL,
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
            isMigrated INTEGER NOT NULL
          )
        ''');
        await db.execute('CREATE INDEX idx_area ON voters(area)');
        await db.execute('CREATE INDEX idx_ward ON voters(ward)');
        await db.execute('CREATE INDEX idx_name ON voters(name)');
        await db.execute('CREATE INDEX idx_voterNo ON voters(voterNo)');
      },
    );
  }

  Future<int> saveVotersFromApi(List<Voter> voterList) async {
    if (voterList.isEmpty) return 0;
    final db = await instance.database;

    await db.transaction((txn) async {
      var batch = txn.batch();
      for (var v in voterList) {
        batch.rawInsert(
          '''
          INSERT OR REPLACE INTO voters (serialNo, voterNo, name, gender, dob, fatherOrHusband, mother, occupation, address, area, union_or_ward_id, union_ward_id, union_or_ward_name, union_ward_name, ward, centerName, isMigrated)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''',
          [
            v.serialNo,
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
      query += ' AND (gender = ? OR gender LIKE ?)';
      args.addAll([gender, '%$gender%']);
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
      query += ' AND (gender = ? OR gender LIKE ?)';
      args.addAll([gender, '%$gender%']);
    }
    if (ward != null && ward != 'সকল') {
      query += ' AND ward = ?';
      args.add(ward);
    }
    if (area != null && area != 'সকল') {
      query += ' AND area = ?';
      args.add(area);
    }

    query += ' ORDER BY CAST(serialNo AS INTEGER) ASC LIMIT ? OFFSET ?';
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

  // 🔴 অফলাইন ফ্যামিলি সার্চ (পিতা-মাতা উভয়ের মূল নাম ৫০% মিল এবং লিঙ্গভেদে সন্তান ৭০% মিল)
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

    // ১. পিতা ও মাতা উভয় নামের মূল অংশ একত্রে অন্তত ৫০% মিল (সহোদর ভাই-বোন)
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

    // ২. লিঙ্গ অনুযায়ী সন্তান নির্বাচন (৭০% মিল):
    // পুরুষ হলে পিতার ঘরে নিজের নাম, মহিলা হলে মাতার ঘরে নিজের নাম
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
      '%$coreFather%', '%$coreMother%', // স্কোর ৪০: পিতা-মাতা উভয় মিল
      '%$coreSelf%', '%$coreSelf%', // স্কোর ২৫: সন্তান মিল
    ];

    final result = await db.rawQuery(sql, queryParams);
    return result.map((json) => Voter.fromMap(json)).toList();
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
            'SELECT COUNT(DISTINCT centerName) FROM voters WHERE centerName != ""',
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

    final centerBreakdown = await db.rawQuery('''
      SELECT centerName as center,
             MIN(CAST(serialNo AS INTEGER)) as startSerial,
             MAX(CAST(serialNo AS INTEGER)) as endSerial,
             COUNT(*) as totalCount
      FROM voters
      WHERE centerName != ""
      GROUP BY centerName
      ORDER BY centerName ASC
    ''');

    return {
      'totalVoters': totalVoters,
      'migratedVoters': 0,
      'totalCenters': totalCenters,
      'totalAreas': totalAreas,
      'areaBreakdown': areaBreakdown,
      'centerBreakdown': centerBreakdown,
    };
  }
}
