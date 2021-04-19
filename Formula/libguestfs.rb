require "digest"

class OsxfuseRequirement < Requirement
  fatal true

  satisfy(build_env: false) { self.class.binary_osxfuse_installed? }

  def self.binary_osxfuse_installed?
    File.exist?("/usr/local/include/osxfuse/fuse/fuse.h") &&
      !File.symlink?("/usr/local/include/osxfuse/fuse")
  end

  env do
    unless HOMEBREW_PREFIX.to_s == "/usr/local"
      ENV.append_path "HOMEBREW_LIBRARY_PATHS", "/usr/local/lib"
      ENV.append_path "HOMEBREW_INCLUDE_PATHS", "/usr/local/include/fuse"
    end
  end

  def message
    "macFUSE is required to build libguestfs. Please run `brew install --cask macfuse` first."
  end
end

class Libguestfs < Formula
  desc "Tools for accessing and modifying virtual machine disk images"
  homepage "https://libguestfs.org/"
  url "https://download.libguestfs.org/1.44-stable/libguestfs-1.44.1.tar.gz"
  sha256 "72b7dcdd32da1c17c932cf5a0a70b3bd68bc93e94828ad66a539f2e616adb025"

  depends_on "autoconf" => :build
  depends_on "automake" => :build
  depends_on "bison" => :build # macOS bison is one minor revision too old
  depends_on "gnu-sed" => :build # some of the makefiles expect gnu sed functionality
  depends_on "libtool" => :build
  depends_on "ocaml" => :build
  depends_on "ocaml-findlib" => :build
  depends_on "pkg-config" => :build
  depends_on "augeas"
  depends_on "cdrtools"
  depends_on "coreutils"
  depends_on "cpio"
  depends_on "flex"
  depends_on "glib"
  depends_on "gperf"
  depends_on "hivex"
  depends_on "jansson"
  depends_on "libmagic"
  depends_on "libvirt"
  depends_on "pcre"
  depends_on "qemu"
  depends_on "readline"
  depends_on "xz"

  uses_from_macos "libxml2"
  uses_from_macos "ncurses"

  on_macos do
    depends_on OsxfuseRequirement => :build
  end

  # the linux support is a bit of a guess, since homebrew doesn't currently build bottles for libvirt
  # that means brew test-bot's --build-bottle will fail under ubuntu-latest runners
  on_linux do
    depends_on "libcap"
    depends_on "libfuse"
  end

  # Since we can't build an appliance, the recommended way is to download a fixed one.
  resource "fixed_appliance" do
    url "https://download.libguestfs.org/binaries/appliance/appliance-1.40.1.tar.xz"
    sha256 "1aaf0bef18514b8e9ebd0c6130ed5188b6f6a7052e4891d5f3620078f48563e6"
  end

  # patch do
  #   # program_name and open_memstream.c
  #   url "https://gist.githubusercontent.com/Amar1729/541e66dff14fec0100931b64f78b8f38/raw/27a13176be00ab7e3a13f3eec536b60709c30043/libguestfs-gnulib.patch"
  #   sha256 "621269d78db5cf15e2961189d7714cfb3b6687bdd4d0d4be6b94b4d866e43c7e"
  # end

  # The two required gnulib patches have been reported to gnulib mailing list, but with little effect so far.
  # patch do
  #   # Add an implementation of open_memstream for BSD/Mac.
  #   # Using Eric Blake's proposal originally published here: https://lists.gnu.org/archive/html/bug-gnulib/2010-04/msg00379.html
  #   # and mentioned again here: http://lists.gnu.org/archive/html/bug-gnulib/2015-02/msg00083.html
  #   url "https://gist.githubusercontent.com/shulima/93138eb342fe94273edd/raw/c75eac3a7f536dca526f52cd8cb5c0d6ce8beecc/gnulib-open_memstream.patch"
  #   sha256 "d62f539def7300e4155bf2447b3c22049938a279957a4a97964d2d04440b58ce"
  # end
  # patch do
  #   # Add a program_name equivalent for Mac.
  #   # http://lists.gnu.org/archive/html/bug-gnulib/2015-02/msg00078.html
  #   url "https://gist.githubusercontent.com/shulima/d851f8f35526db5e2fe9/raw/f80f6a73ec102bbdea2394d9bd3482b400853f2c/gnulib-program_name.patch"
  #   sha256 "d17d1962b98a3418a335915de8a2da219e4598d42c24555bbbc5b0c1177dd38c"
  # end

  def install
    ENV["FUSE_CFLAGS"] = "-D_FILE_OFFSET_BITS=64 -D_DARWIN_USE_64_BIT_INODE -I/usr/local/include/osxfuse/fuse"
    ENV["FUSE_LIBS"] = "-losxfuse -pthread -liconv"

    %w[
      ncurses
      augeas
      jansson
      hivex
    ].each do |ext|
      ENV.prepend_path "PKG_CONFIG_PATH", Formula[ext].opt_lib/"pkgconfig"
    end

    args = [
      "--disable-dependency-tracking",
      "--disable-silent-rules",
      "--prefix=#{prefix}",
      "--with-distro=DARWIN",
      "--disable-probes",
      "--disable-appliance",
      "--disable-daemon",
      "--disable-ocaml",
      "--disable-lua",
      "--disable-haskell",
      "--disable-erlang",
      "--disable-gobject",
      "--disable-golang",
      "--disable-ruby",
      "--disable-golang",
      "--disable-php",
      "--disable-perl",
      "--disable-python",
    ]

    ENV["HAVE_RPM_FALSE"] = "#"
    ENV["HAVE_DPKG_FALSE"] = "#"
    ENV["HAVE_PACMAN_FALSE"] = "#"

    system "./configure", *args

    # Build fails with just 'make install'
    # fix for known race condition: https://bugzilla.redhat.com/show_bug.cgi?id=1614502
    # ENV.deparallelize { system "make", "-C", "builder", "index-parse.c" }
    # system "make", "-C", "builder", "index-scan.c"
    # ENV.deparallelize { system "make", "-C", "builder" }
    system "make"
    system "make", "check" # 5 FAILs :/

    system "make", "INSTALLDIRS=vendor", "DESTDIR=#{buildpath}", "install"

    libguestfs_path = "#{prefix}/var/libguestfs-appliance"
    mkdir_p libguestfs_path
    resource("fixed_appliance").stage(libguestfs_path)

    bin.install_symlink Dir["bin/*"]
  end

  def caveats
    <<~EOS
      A fixed appliance is required for libguestfs to work on Mac OS X.
      This formula downloads the appliance and places it in:
      #{prefix}/var/libguestfs-appliance

      To use the appliance, add the following to your shell configuration:
      export LIBGUESTFS_PATH=#{prefix}/var/libguestfs-appliance
      and use libguestfs binaries in the normal way.

      For compilers to find libguestfs you may need to set:
        export LDFLAGS="-L#{prefix}/lib"
        export CPPFLAGS="-I#{prefix}/include"

      For pkg-config to find libguestfs you may need to set:
        export PKG_CONFIG_PATH="#{prefix}/lib/pkgconfig"

    EOS
  end

  test do
    ENV["LIBGUESTFS_PATH"] = "#{prefix}/var/libguestfs-appliance"
    system "#{bin}/libguestfs-test-tool", "-t 180"
  end
end
