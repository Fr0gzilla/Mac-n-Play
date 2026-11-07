cask "macnplay" do
  version "1.2.1"
  sha256 "363cacde229d897e1d03d74eae1b25834552c622c501af0c397ef13bad7a550b"

  url "https://github.com/Fr0gzilla/Mac-n-Play/releases/download/v#{version}/Mac-n-Play-#{version}.dmg"
  name "Mac'n'Play"
  desc "Play your PS4 or PS5 on your Mac with your controller (Remote Play)"
  homepage "https://github.com/Fr0gzilla/Mac-n-Play"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on arch: :arm64
  depends_on macos: :sequoia

  app "Mac'n'Play.app"

  zap trash: [
    "~/Library/Application Support/MacnPlay",
    "~/Library/Caches/MacnPlay",
    "~/Library/Preferences/com.macnplay.MacnPlay.plist",
    "~/Library/Preferences/com.macnplay.pl_render_params.plist",
    "~/Library/Saved Application State/com.macnplay.MacnPlay.savedState",
  ]

  caveats <<~EOS
    Mac'n'Play n'est pas signé par Apple. Au premier lancement, autorisez-le dans
    Réglages Système › Confidentialité et sécurité › Ouvrir quand même,
    ou lancez :
      xattr -dr com.apple.quarantine "/Applications/Mac'n'Play.app"
  EOS
end
