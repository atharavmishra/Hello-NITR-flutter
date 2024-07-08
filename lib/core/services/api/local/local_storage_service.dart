import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hello_nitr/core/constants/app_constants.dart';
import 'package:logging/logging.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:hello_nitr/models/user.dart';
import 'package:hello_nitr/models/login.dart';
import 'dart:convert';

class LocalStorageService {
  static Database? _database;
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  static final Logger _logger = Logger('LocalStorageService');

  // Get database instance or initialize if it doesn't exist
  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB(AppConstants.dbName);
    return _database!;
  }

  // Initialize the database
  static Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  // Create the user table in the database
  static Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE ${AppConstants.userTable} (
        empCode TEXT PRIMARY KEY,
        designation TEXT,
        departmentCode TEXT,
        departmentName TEXT,
        firstName TEXT,
        middleName TEXT,
        lastName TEXT,
        mobile TEXT,
        personalEmail TEXT,
        email TEXT,
        workPhone TEXT,
        residencePhone TEXT,
        quarterAlpha TEXT,
        quarterNo TEXT,
        employeeType TEXT,
        roomNo TEXT,
        photo TEXT
      )
    ''');
  }

  // Initialize the database
  static Future<void> initDatabase() async {
    await database;
  }

  // Save a user to the database
  static Future<void> saveUser(User user) async {
    final db = await database;
    await db.insert(
      AppConstants.userTable,
      user.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Get users with filter and sorting order
  static Future<List<User>> getUsers(
      int offset, int limit, String filter, bool isAscending) async {
    final db = await database;

    // Build the where clause and arguments based on the filter
    String? whereClause;
    List<dynamic>? whereArgs;

    if (filter != 'All Employee') {
      whereClause = 'employeeType = ?';
      whereArgs = [filter];
    }

    final orderBy = 'firstName ${isAscending ? 'ASC' : 'DESC'}';

    final List<Map<String, dynamic>> maps = await db.query(
      AppConstants.userTable,
      limit: limit,
      offset: offset,
      orderBy: orderBy,
      where: whereClause,
      whereArgs: whereArgs,
    );

    return List.generate(maps.length, (i) {
      return User.fromJson(maps[i]);
    });
  }

  // Get the count of users based on the filter
  static Future<int> getUserCount(String filter) async {
    final db = await database;

    // Build the where clause and arguments based on the filter
    String? whereClause;
    List<dynamic>? whereArgs;

    if (filter != 'All Employee') {
      whereClause = 'employeeType = ?';
      whereArgs = [filter];
    }

    final countQuery = await db.rawQuery(
      'SELECT COUNT(*) FROM ${AppConstants.userTable} ${whereClause != null ? 'WHERE $whereClause' : ''}',
      whereArgs,
    );

    return Sqflite.firstIntValue(countQuery) ?? 0;
  }

  // Search for users based on the query string
  static Future<List<User>> searchUsers(
    int offset,
    int limit,
    String query,
  ) async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      AppConstants.userTable,
      where:
          '''mobile LIKE ?
            OR firstName LIKE ?
             OR lastName LIKE ?
              OR middleName LIKE ?
               OR email LIKE ? 
               OR personalEmail LIKE ?
                OR workPhone LIKE ?
                 ''',
      whereArgs: [
        '%$query%',
        '%$query%',
        '%$query%',
        '%$query%',
        '%$query%',
        '%$query%',
        '%$query%'
      ],
      limit: limit,
      offset: offset,
      orderBy: 'firstName ASC',
    );

    return List.generate(maps.length, (i) {
      return User.fromJson(maps[i]);
    });
  }

  // Search users with filter
  static Future<List<User>> searchUsersFiltered(
    int offset,
    int limit,
    String query,
    String filter,
  ) async {
    final db = await database;

    String whereClause = '''
      (mobile LIKE ?
      OR firstName LIKE ?
      OR lastName LIKE ?
      OR middleName LIKE ?
      OR email LIKE ? 
      OR personalEmail LIKE ?
      OR workPhone LIKE ?)
    ''';

    List<dynamic> whereArgs = [
      '%$query%',
      '%$query%',
      '%$query%',
      '%$query%',
      '%$query%',
      '%$query%',
      '%$query%'
    ];

    // Add filter condition if it's not 'All Employee'
    if (filter != 'All Employee') {
      whereClause += ' AND employeeType = ?';
      whereArgs.add(filter);
    }

    final List<Map<String, dynamic>> maps = await db.query(
      AppConstants.userTable,
      where: whereClause,
      whereArgs: whereArgs,
      limit: limit,
      offset: offset,
      orderBy: 'firstName ASC',
    );

    return List.generate(maps.length, (i) {
      return User.fromJson(maps[i]);
    });
  }

  // Search users by department
  static Future<List<User>> searchUsersByDepartment(
    String query,
    String department,
    int offset,
    int limit, {
    bool ascending = true,
  }) async {
    final db = await database;
    final orderBy = ascending ? 'ASC' : 'DESC';
    final result = await db.rawQuery('''
      SELECT * FROM ${AppConstants.userTable}
      WHERE (firstName || ' ' || IFNULL(middleName, '') || ' ' || lastName LIKE ? 
             OR mobile LIKE ? 
             OR email LIKE ?)
        AND departmentName = ?
      ORDER BY firstName $orderBy
      LIMIT ? OFFSET ?
    ''', ['%$query%', '%$query%', '%$query%', department, limit, offset]);

    return result.map((json) => User.fromJson(json)).toList();
  }

  // Get the list of departments from the database and also sort them alphabetically
static Future<List<String>> getDepartments() async {
  final db = await database;

  final List<Map<String, dynamic>> maps = await db.query(
    AppConstants.userTable,
    columns: ['departmentName'],
    distinct: true,
  );

  List<String> departments = List.generate(maps.length, (i) {
    return maps[i]['departmentName'];
  });

  departments.sort(); // Sort the departments alphabetically

  return departments;
}


  // Save login response to secure storage
  static Future<void> saveLoginResponse(LoginResponse loginResponse) async {
    try {
      String loginJson = jsonEncode(loginResponse.toJson());
      await _secureStorage.write(
          key: AppConstants.currentLoggedInUserKey, value: loginJson);
    } catch (e) {
      _logger.severe('Error saving login response: $e');
    }
  }

  // Get login time from secure storage
  static Future<DateTime?> getLoginTime() async {
    try {
      String? loginJson = await _secureStorage.read(key: AppConstants.currentLoggedInUserKey);
      if (loginJson != null) {
        LoginResponse loginResponse = LoginResponse.fromJson(jsonDecode(loginJson));
        return loginResponse.loginTime;
      } else {
        return null;
      }
    } catch (e) {
      _logger.severe('Error retrieving login time: $e');
      return null;
    }
  }

  // Get login response from secure storage
  static Future<LoginResponse?> getLoginResponse() async {
    try {
      String? loginJson = await _secureStorage.read(key: AppConstants.currentLoggedInUserKey);
      if (loginJson != null) {
        return LoginResponse.fromJson(jsonDecode(loginJson));
      } else {
        return null;
      }
    } catch (e) {
      _logger.severe('Error retrieving login response: $e');
      return null;
    }
  }

  // Delete login response from secure storage
  static Future<void> deleteLoginResponse() async {
    try {
      await _secureStorage.delete(key: AppConstants.currentLoggedInUserKey);
    } catch (e) {
      _logger.severe('Error deleting login response: $e');
    }
  }

  // Save PIN to secure storage
  static Future<void> savePin(String pin) async {
    try {
      await _secureStorage.write(key: AppConstants.pinKey, value: pin);
    } catch (e) {
      _logger.severe('Error saving PIN: $e');
    }
  }

  // Get PIN from secure storage
  static Future<String?> getPin() async {
    try {
      return await _secureStorage.read(key: AppConstants.pinKey);
    } catch (e) {
      _logger.severe('Error retrieving PIN: $e');
      return null;
    }
  }

  // Delete PIN from secure storage
  static Future<void> deletePin() async {
    try {
      await _secureStorage.delete(key: AppConstants.pinKey);
    } catch (e) {
      _logger.severe('Error deleting PIN: $e');
    }
  }

  // Log out by deleting login response and PIN from secure storage
  static Future<void> logout() async {
    await deleteLoginResponse();
    await deletePin();
  }

  // Check if a user is logged in
  static Future<bool> checkIfUserIsLoggedIn() async {
    LoginResponse? currentUser = await getLoginResponse();
    return currentUser != null;
  }

  // Get the current user's name
  static Future<String?> getCurrentUserName() async {
    LoginResponse? currentUser = await getLoginResponse();
    return currentUser?.firstName;
  }

  // Get the current user
  static Future<User?> getCurrentUser() async {
    LoginResponse? currentUser = await getLoginResponse();
    return currentUser != null ? convertLoginResponseToUser(currentUser) : null;
  }

  // Convert a LoginResponse object to a User object
  static User convertLoginResponseToUser(LoginResponse loginResponse) {
    return User(
      empCode: loginResponse.empCode ?? '',
      designation: loginResponse.designation ?? '',
      departmentCode: loginResponse.departmentCode ?? '',
      departmentName: loginResponse.departmentName ?? '',
      firstName: loginResponse.firstName ?? '',
      middleName: loginResponse.middleName,
      lastName: loginResponse.lastName ?? '',
      mobile: loginResponse.mobile ?? '',
      personalEmail: loginResponse.personalEmail,
      email: loginResponse.email ?? '',
      workPhone: loginResponse.workPhone,
      residencePhone: loginResponse.residencePhone,
      quarterAlpha: loginResponse.quarterAlpha,
      quarterNo: loginResponse.quarterNo,
      employeeType: loginResponse.employeeType ?? '',
      roomNo: loginResponse.roomNo,
      photo: loginResponse.photo,
    );
  }
}
