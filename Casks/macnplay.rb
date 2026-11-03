cask "macnplay" do
  version "1.0.0"
  sha256 "db62731dc07b21b62a1bb2d187dd35c3ef1b6d34fc1886ec1aeaf6f7aa656010"

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
    "~/Library/Preferences/com.macnplay.MacnPlay.plist",
  ]

  caveats <<~EOS
    Mac'n'Play n'est pas signé par Apple. Au premier lancement, autorisez-le dans
    Réglages Système › Confidentialité et sécurité › Ouvrir quand même,
    ou lancez :
      xattr -dr com.apple.quarantine "/Applications/Mac'n'Play.app"
  EOS
end
