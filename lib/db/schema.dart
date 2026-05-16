/// SQLite schema. Bump [kSchemaVersion] when adding columns/tables and
/// append a step to [migrationSteps].
const int kSchemaVersion = 3;

/// Statements that build the schema for a fresh install.
const List<String> kCreateStatements = [
  '''
  CREATE TABLE materials (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE COLLATE NOCASE,
    created_at INTEGER NOT NULL
  )
  ''',
  '''
  CREATE TABLE qualities (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    material_id INTEGER NOT NULL REFERENCES materials(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    UNIQUE(material_id, name) ON CONFLICT ABORT
  )
  ''',
  '''
  CREATE TABLE units (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    material_id INTEGER NOT NULL REFERENCES materials(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    UNIQUE(material_id, name) ON CONFLICT ABORT
  )
  ''',
  '''
  CREATE TABLE suppliers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE COLLATE NOCASE,
    created_at INTEGER NOT NULL
  )
  ''',
  '''
  CREATE TABLE sites (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE COLLATE NOCASE,
    plot_count INTEGER NOT NULL DEFAULT 0,
    created_at INTEGER NOT NULL
  )
  ''',
  '''
  CREATE TABLE expenses (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    material_id INTEGER NOT NULL REFERENCES materials(id),
    quality_id  INTEGER REFERENCES qualities(id),
    unit_id     INTEGER REFERENCES units(id),
    cost        REAL    NOT NULL,
    quantity    REAL    NOT NULL,
    date        TEXT    NOT NULL,
    note        TEXT,
    person_name TEXT    NOT NULL,
    from_kind        TEXT    NOT NULL CHECK(from_kind IN ('supplier','site','plot')),
    from_supplier_id INTEGER REFERENCES suppliers(id),
    from_site_id     INTEGER REFERENCES sites(id),
    from_plot_number INTEGER,
    to_kind          TEXT    NOT NULL CHECK(to_kind IN ('supplier','site','plot')),
    to_supplier_id   INTEGER REFERENCES suppliers(id),
    to_site_id       INTEGER REFERENCES sites(id),
    to_plot_number   INTEGER,
    created_at  INTEGER NOT NULL,
    updated_at  INTEGER NOT NULL
  )
  ''',
  'CREATE INDEX idx_exp_material  ON expenses(material_id)',
  'CREATE INDEX idx_exp_date      ON expenses(date)',
  'CREATE INDEX idx_exp_from_supp ON expenses(from_supplier_id)',
  'CREATE INDEX idx_exp_from_site ON expenses(from_site_id)',
  'CREATE INDEX idx_exp_to_supp   ON expenses(to_supplier_id)',
  'CREATE INDEX idx_exp_to_site   ON expenses(to_site_id)',
];

/// onUpgrade ladder. Map key = the version you're upgrading TO.
final Map<int, List<String>> migrationSteps = {
  // v2 added 6 free-text route columns to expenses.
  2: [
    'ALTER TABLE expenses ADD COLUMN from_site     TEXT',
    'ALTER TABLE expenses ADD COLUMN from_supplier TEXT',
    'ALTER TABLE expenses ADD COLUMN from_plot     TEXT',
    'ALTER TABLE expenses ADD COLUMN to_site       TEXT',
    'ALTER TABLE expenses ADD COLUMN to_supplier   TEXT',
    'ALTER TABLE expenses ADD COLUMN to_plot       TEXT',
  ],
  // v3 introduces structured route master data (suppliers, sites) and
  // rebuilds the expenses table. v2 free-text route info is dropped per the
  // approved plan — v2 was test-only.
  3: [
    '''
    CREATE TABLE suppliers (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL UNIQUE COLLATE NOCASE,
      created_at INTEGER NOT NULL
    )
    ''',
    '''
    CREATE TABLE sites (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL UNIQUE COLLATE NOCASE,
      plot_count INTEGER NOT NULL DEFAULT 0,
      created_at INTEGER NOT NULL
    )
    ''',
    'DROP TABLE expenses',
    '''
    CREATE TABLE expenses (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      material_id INTEGER NOT NULL REFERENCES materials(id),
      quality_id  INTEGER REFERENCES qualities(id),
      unit_id     INTEGER REFERENCES units(id),
      cost        REAL    NOT NULL,
      quantity    REAL    NOT NULL,
      date        TEXT    NOT NULL,
      note        TEXT,
      person_name TEXT    NOT NULL,
      from_kind        TEXT    NOT NULL CHECK(from_kind IN ('supplier','site','plot')),
      from_supplier_id INTEGER REFERENCES suppliers(id),
      from_site_id     INTEGER REFERENCES sites(id),
      from_plot_number INTEGER,
      to_kind          TEXT    NOT NULL CHECK(to_kind IN ('supplier','site','plot')),
      to_supplier_id   INTEGER REFERENCES suppliers(id),
      to_site_id       INTEGER REFERENCES sites(id),
      to_plot_number   INTEGER,
      created_at  INTEGER NOT NULL,
      updated_at  INTEGER NOT NULL
    )
    ''',
    'CREATE INDEX idx_exp_material  ON expenses(material_id)',
    'CREATE INDEX idx_exp_date      ON expenses(date)',
    'CREATE INDEX idx_exp_from_supp ON expenses(from_supplier_id)',
    'CREATE INDEX idx_exp_from_site ON expenses(from_site_id)',
    'CREATE INDEX idx_exp_to_supp   ON expenses(to_supplier_id)',
    'CREATE INDEX idx_exp_to_site   ON expenses(to_site_id)',
  ],
};
