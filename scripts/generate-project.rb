require 'xcodeproj'
project = Xcodeproj::Project.new('Leaflit.xcodeproj')
project.build_configurations.each do |config|
  config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '14.0'
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['ARCHS'] = 'arm64'
  config.build_settings['CODE_SIGN_IDENTITY'] = '-'
  config.build_settings['CODE_SIGN_STYLE'] = 'Manual'
  config.build_settings['ENABLE_USER_SCRIPT_SANDBOXING'] = 'YES'
end
core = project.new_target(:framework, 'LeaflitCore', :osx, '14.0')
app = project.new_target(:application, 'Leaflit', :osx, '14.0')
tests = project.new_target(:unit_test_bundle, 'LeaflitTests', :osx, '14.0')
[core, app, tests].each do |target|
  target.build_configurations.each do |config|
    config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = "io.github.magicsih.#{target.name.downcase}"
    config.build_settings['GENERATE_INFOPLIST_FILE'] = 'YES'
    config.build_settings['SWIFT_EMIT_LOC_STRINGS'] = 'NO'
    config.build_settings['ENABLE_HARDENED_RUNTIME'] = 'NO'
    config.build_settings['COMBINE_HIDPI_IMAGES'] = 'YES'
  end
end
core.build_configurations.each { |c| c.build_settings['DEFINES_MODULE'] = 'YES' }
app.build_configurations.each do |c|
  c.build_settings['INFOPLIST_FILE'] = 'Sources/Leaflit/Info.plist'
  c.build_settings['GENERATE_INFOPLIST_FILE'] = 'NO'
  c.build_settings['LD_RUNPATH_SEARCH_PATHS'] = ['$(inherited)', '@executable_path/../Frameworks']
end
def sources(project, target, glob)
  Dir.glob(glob).sort.each { |path| target.source_build_phase.add_file_reference(project.main_group.new_file(path)) }
end
sources(project, core, 'Sources/LeaflitCore/*.swift')
sources(project, app, 'Sources/Leaflit/*.swift')
sources(project, tests, 'Tests/LeaflitTests/*.swift')
sources(project, tests, 'Tests/LeaflitCoreTests/*.swift')
app.add_dependency(core)
app.frameworks_build_phase.add_file_reference(core.product_reference)
embed = app.new_copy_files_build_phase('Embed Frameworks'); embed.dst_subfolder_spec = '10'
build_file = embed.add_file_reference(core.product_reference); build_file.settings = {'ATTRIBUTES' => ['CodeSignOnCopy', 'RemoveHeadersOnCopy']}
web = project.main_group.new_reference('Sources/Leaflit/Web', :group); web.last_known_file_type = 'folder'
app.resources_build_phase.add_file_reference(web)
app.resources_build_phase.add_file_reference(project.main_group.new_file('LICENSE'))
tests.add_dependency(app); tests.add_dependency(core)
tests.frameworks_build_phase.add_file_reference(core.product_reference)
tests.build_configurations.each do |c|
  c.build_settings['TEST_HOST'] = '$(BUILT_PRODUCTS_DIR)/Leaflit.app/Contents/MacOS/Leaflit'
  c.build_settings['BUNDLE_LOADER'] = '$(TEST_HOST)'
  c.build_settings['LD_RUNPATH_SEARCH_PATHS'] = ['$(inherited)', '@executable_path/../Frameworks', '@loader_path/../Frameworks']
end
project.save
scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(app); scheme.add_test_target(tests); scheme.set_launch_target(app)
scheme.save_as('Leaflit.xcodeproj', 'Leaflit', true)
