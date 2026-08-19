/// RULE ZERO — these are the *same* values Noor Majlis and the QC dashboard use.
///
/// One Supabase project (`noor-demo`), one URL, one anon key. Sharik creates no
/// schema: every table it touches already exists. If a column appears to be
/// missing, stop and raise it — never add it locally.
class SupabaseConfig {
  const SupabaseConfig._();

  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://itmzwslepexeqixuxjca.supabase.co',
  );

  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Iml0bXp3c2xlcGV4ZXFpeHV4amNhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODcxMzMxMTgsImV4cCI6MjEwMjcwOTExOH0.TTD2CIIXezQRSZ3rdAevaNaa1bqXxNfSwQQI7biEXso',
  );

  /// Single-tenant for the demo. Every row in the shared schema carries it.
  static const String tenantId = '10000000-0000-4000-a000-000000000001';

  /// A seller sees an order only once QC has released it.
  ///
  /// This is a commercial rule, not a technical one: a seller seeing an order
  /// while the client is still negotiating is a disaster. With RLS off for the
  /// demo, every order query carries this filter.
  static const List<String> visibleOrderStatuses = <String>[
    'released',
    'in_production',
    'inspection',
    'packed',
    'shipped',
    'arrived',
    'closed',
  ];
}
