class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://enerlytix-lake.vercel.app',
  );

  // AUTH
  static const String loginPath = '/api/auth/login';
  static const String registerPath = '/api/auth/register';

  // USER
  static const String userDashboardPath = '/api/user/dashboard';
  static const String userMonitoringPath = '/api/user/monitoring';
  static const String buyTokenPath = '/api/user/buyToken';
  static const String userSetWattPath = '/api/user/setWatt';

  // ADMIN
  static const String adminDashboardPath = '/api/admin/dashboard';
  static const String adminTokensPath = '/api/admin/tokens';
  static const String adminTopupPath = '/api/admin/topupToken';
  static const String adminUpdateKwhPath = '/api/admin/updateKwh';
  static const String adminMonitoringPath = '/api/admin/monitoring';

  // FULL URLS
  static String loginUrl() => '$baseUrl$loginPath';
  static String registerUrl() => '$baseUrl$registerPath';

  // USER
  static String userDashboardUrl(int userId) =>
      '$baseUrl$userDashboardPath?userId=$userId';
  static String userMonitoringUrl(int userId) =>
      '$baseUrl$userMonitoringPath?userId=$userId';
  static String buyTokenUrl() => '$baseUrl$buyTokenPath';
  static String userSetWattUrl() => '$baseUrl$userSetWattPath';

  // ADMIN
  static String adminDashboardUrl() => '$baseUrl$adminDashboardPath';
  static String adminTokensUrl() => '$baseUrl$adminTokensPath';
  static String adminTopupUrl() => '$baseUrl$adminTopupPath';
  static String adminUpdateKwhUrl() => '$baseUrl$adminUpdateKwhPath';
  static String adminMonitoringUrl() => '$baseUrl$adminMonitoringPath';
}