/// Exclusions applied to every root unless the user changes them.
library;

/// Files and folders that must never enter the index (plan appendix B).
const List<String> defaultExcludeGlobs = <String>[
  // Office lock files.
  r'~$*',
  // Generic temporary files and LibreOffice locks.
  '*.tmp',
  '~WRL*.tmp',
  r'.~lock.*#',
  // Shell noise.
  'Thumbs.db',
  'desktop.ini',
  '.DS_Store',
  // Dependency and VCS directories.
  '.git/',
  '.svn/',
  'node_modules/',
  '__pycache__/',
  '.venv/',
  // Recycle bin and system folders.
  r'$RECYCLE.BIN/',
  'System Volume Information/',
  // DocNest's own staging, trash and cache directory.
  '.docnest/',
];

/// Directories that may never become a whitelisted root (plan appendix B).
const List<String> deniedRootNames = <String>[
  'Windows',
  'Program Files',
  'Program Files (x86)',
  'ProgramData',
  'AppData',
];
