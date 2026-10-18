cask "leaflit" do
  version "__VERSION__"
  sha256 "__SHA256__"

  url "https://github.com/magicsih/leaflit/releases/download/v#{version}/Leaflit-#{version}-macos-arm64.zip"
  name "Leaflit"
  desc "Read-only Markdown viewer with offline diagrams and math"
  homepage "https://github.com/magicsih/leaflit"

  depends_on arch: :arm64
  depends_on macos: :sonoma

  app "Leaflit-#{version}/Leaflit.app"
  binary "#{appdir}/Leaflit.app/Contents/Helpers/leaflit"
end
