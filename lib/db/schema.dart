/// SQLite schema. Bump [kSchemaVersion] when adding columns/tables and
/// append a step to [migrationSteps].
const int kSchemaVersion = 1;

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
    created_at  INTEGER NOT NULL,
    updated_at  INTEGER NOT NULL
  )
  ''',
  'CREATE INDEX idx_exp_material ON expenses(material_id)',
  'CREATE INDEX idx_exp_date     ON expenses(date)',
];

/// onUpgrade ladder. Map index = the version you're upgrading TO.
/// If we ever ship v2, add migrationSteps[2] = ['ALTER TABLE ...'].
final Map<int, List<String>> migrationSteps = {
  // future: 2: ['ALTER TABLE expenses ADD COLUMN foo TEXT'],
};
