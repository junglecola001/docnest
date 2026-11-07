/// DocNest wire protocol. Pure Dart, no Flutter, no `dart:io`.
///
/// Every type here maps 1:1 to a JSON shape in `docs/protocol/openapi.yaml`;
/// change both in the same commit.
library;

export 'src/api_paths.dart';
export 'src/dto/doc_dto.dart';
export 'src/dto/error_dto.dart';
export 'src/dto/event_dto.dart';
export 'src/dto/host_info_dto.dart';
export 'src/dto/pair_dtos.dart';
export 'src/dto/root_dto.dart';
export 'src/dto/upload_dtos.dart';
export 'src/json.dart';
export 'src/pairing_link.dart';
export 'src/protocol_version.dart';
