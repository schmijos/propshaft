require "test_helper"
require "minitest/mock"
require "propshaft/asset"
require "propshaft/load_path"
require "propshaft/output_path"

class Propshaft::OutputPathTest < ActiveSupport::TestCase
  setup do
    @manifest    = {
      ".manifest.json": ".manifest.json",
      "one.txt": "one-f2e1ec14.txt",
      "one.txt.map": "one-f2e1ec15.txt.map",
      "file-already-abcdefVWXYZ0123456789_-.digested.css": "file-already-abcdefVWXYZ0123456789_-.digested.css"
    }.stringify_keys
    @output_path = Propshaft::OutputPath.new(Pathname.new("#{__dir__}/../fixtures/output"), @manifest)
  end

  test "files" do
    files = @output_path.files

    file = files["one-f2e1ec14.txt"]
    assert_equal "one.txt", file[:logical_path]
    assert_equal "f2e1ec14", file[:digest]
    assert file[:mtime].is_a?(Time)

    assert files["file-already-abcdefVWXYZ0123456789_-.digested.css"]
  end

  test "clean always keeps most current versions" do
    @output_path.clean(0, 0)
    assert @output_path.path.join(@manifest["one.txt"])
    assert @output_path.path.join(@manifest[".manifest.json"])
  end

  test "clean keeps versions of assets that no longer exist" do
    removed = output_asset("no-longer-in-manifest.txt", "current")
    @output_path.clean(1, 0)
    assert File.exist?(removed)
  ensure
    FileUtils.rm(removed) if File.exist?(removed)
  end

  test "clean keeps the correct number of versions" do
    old     = output_asset("by_count.txt", "old", created_at: Time.now - 300)
    current = output_asset("by_count.txt", "current", created_at: Time.now - 180)

    @output_path.clean(1, 0)

    assert File.exist?(current)
    assert_not File.exist?(old)
  ensure
    FileUtils.rm(old) if File.exist?(old)
    FileUtils.rm(current) if File.exist?(current)
  end

  test "clean keeps the correct number of versions regardless of the file extension" do
    old     = output_asset("by_count.txt.map", "old", created_at: Time.now - 300)
    current = output_asset("by_count.txt.map", "current", created_at: Time.now - 180)

    assert File.exist?(current)
    assert File.exist?(old)

    @output_path.clean(1, 0)

    assert File.exist?(current)
    assert_not File.exist?(old), "#{old} should not exist"
  ensure
    FileUtils.rm(old) if File.exist?(old)
    FileUtils.rm(current) if File.exist?(current)
  end

  test "clean keeps all versions under a certain age" do
    old     = output_asset("by_age.txt", "old")
    current = output_asset("by_age.txt", "current")

    @output_path.clean(0, 3600)

    assert File.exist?(current)
    assert File.exist?(old)
  ensure
    FileUtils.rm(old) if File.exist?(old)
    FileUtils.rm(current) if File.exist?(current)
  end

  test "clean keeps the correct number of predigested versions" do
    old     = output_asset("Vue3Lottie-23af1d5aa7baee8b1ca8.digested.js", "old", created_at: Time.now - 300)
    current = output_asset("Vue3Lottie-337a4df42c71a547bccd.digested.js", "current", created_at: Time.now - 180)

    @output_path.clean(1, 0)

    assert File.exist?(current), "#{current} should still exist"
    assert_not File.exist?(old), "#{old} should be removed"
  ensure
    FileUtils.rm(old) if File.exist?(old)
    FileUtils.rm(current) if File.exist?(current)
  end

  private
    def output_asset(filename, content, created_at: Time.now)
      load_path = Propshaft::LoadPath.new([], compilers: Propshaft::Compilers.new(nil))
      asset = Propshaft::Asset.new(nil, logical_path: filename, load_path: load_path)
      asset.stub :content, content do
        output_path = @output_path.path.join(asset.digested_path)
        `touch -mt #{created_at.strftime('%y%m%d%H%M')} #{output_path}`
        output_path
      end
    end
end
