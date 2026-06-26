# Changelog

## Unreleased

### Added
- Conditional rules via `Pipeline#when` and `Rules::Conditional`
- Cross-field schema definitions via `Schema` / `CsvPipeline.from_schema`
- YAML pipeline configuration via `Pipeline.from_yaml` / `CsvPipeline.from_yaml`
- JSON and CSV export with errors column on `ProcessingResult`
- Optional fail-fast mode on `Pipeline` (`fail_fast: true`)
- Configurable blank semantics via `Blank.configure` and `BlankPolicy`
- Internationalized error messages via `Messages` (`:en`, `:es`)
- `RuleInvoker` for safe field-rule dispatch (Procs and plain callables)
- `HeaderValidator` with duplicate, blank, and extra-column checks in strict mode
- `Record#fresh_copy`, `#changed_fields`, and `#changed?`
- `Pipeline#run(record, fresh: true)` for re-processing without error accumulation
- `Pipeline#process(materialize: false)` returning `LazyProcessingResult`
- `Pipeline#required` / `#optional` DSL to prevent rule-order footguns
- `Pipeline.customer_import` and `CsvPipeline.customer_pipeline` factory
- `ProcessingResult#valid_hashes`, `#invalid_hashes`, and `#errors_json`
- UTF-8 BOM stripping for file and inline CSV sources
- Configurable `encoding:` option on `CsvReader`
- `examples/customer_pipeline.rb` documenting canonical rule ordering

### Fixed
- `BlockRule` no longer calls `#arity` on plain callable objects
- Duplicate-header errors now reference the header row, not the first data row
- Extra CSV columns no longer silently create blank-key fields in strict mode
- `EmailFormat` works through the block DSL without an explicit pattern

### Changed
- Customer pipeline applies `DefaultValue` after email validations (safer ordering)
- `ProcessingResult#to_h` includes `source_data` and `changed_fields` per record
