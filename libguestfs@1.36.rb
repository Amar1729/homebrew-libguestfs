class LibguestfsAT136 < Formula
  desc "Set of tools for accessing and modifying virtual machine (VM) disk images"
  homepage "http://libguestfs.org/"

  url "http://libguestfs.org/download/1.36-stable/libguestfs-1.36.15.tar.gz"
  sha256 "63f0c53a9e79801f4e74254e5b1f6450febb452aeb395d8d3d90f816cd8058ec"

  depends_on "autoconf" => :build
  depends_on "automake" => :build
  depends_on "bison" => :build # macOS bison is one minor revision too old
  depends_on "gnu-sed" => :build # some of the makefiles expect gnu sed functionality
  depends_on "libtool" => :build
  depends_on "pkg-config" => :build
  depends_on "truncate" => :build
  depends_on "augeas"
  depends_on "cdrtools"
  depends_on "gettext"
  depends_on "glib"
  depends_on "pcre"
  depends_on "qemu"
  depends_on "readline"
  depends_on "xz"
  depends_on "yajl"

  # Since we can't build an appliance, the recommended way is to download a fixed one.
  resource "fixed_appliance" do
    url "http://download.libguestfs.org/binaries/appliance/appliance-1.36.1.tar.xz"
    sha256 "45040a9dacf597870108fde0ac395f340d2469bf3cee2d1f2cc1bcfb46c89bce"
  end

  patch do
    # Change program_name to avoid collision with gnulib
    url "https://gist.githubusercontent.com/Amar1729/541e66dff14fec0100931b64f78b8f38/raw/b543e5ee87c76c6a5dadc478ea272e141ee67665/libguestfs-gnulib.patch"
    sha256 "a83b5330b58e5a3c386548558580b421971b4eb1a2c6ed60eee5a8f967d39a41"
  end
  patch do
    # Fix rpc/xdr.h includes (on macOS, include rpc/types.h first)
    url "https://gist.githubusercontent.com/Amar1729/1a9cf7f3e4d7ea598676405fbf81a609/raw/502be6eeeedfa8134a97c75659f74d709a133866/rpc-xdr.patch"
    sha256 "5c649da91f969126929c4cc90ed17d08cd0d5990c79eb214aa3c8a061eb2ab89"
  end

  def install
    ENV["LIBTINFO_CFLAGS"] = "-I#{Formula["ncurses"].opt_include}"
    ENV["LIBTINFO_LIBS"] = "-lncurses"

    ENV["FUSE_CFLAGS"] = "-D_FILE_OFFSET_BITS=64 -D_DARWIN_USE_64_BIT_INODE -I/usr/local/include/osxfuse/fuse"
    ENV["FUSE_LIBS"] = "-losxfuse -pthread -liconv"

    ENV["AUGEAS_CFLAGS"] = "-I#{Formula["augeas"].opt_include}"
    ENV["AUGEAS_LIBS"] = "-L#{Formula["augeas"].opt_lib}"

    args = [
      "--disable-probes",
      "--disable-appliance",
      "--disable-daemon",
      "--disable-ocaml",
      "--disable-lua",
      "--disable-haskell",
      "--disable-erlang",
      "--disable-gtk-doc-html",
      "--disable-gobject",
      # libvirt fails (error.h issues from gnulib on this version)
      "--without-libvirt",
      "--disable-php",
      "--disable-perl",
      "--disable-golang",
      "--disable-python",
      "--disable-ruby",
    ]

    system "./configure", "--disable-dependency-tracking",
                          "--disable-silent-rules",
                          "--prefix=#{prefix}",
                          *args

    # Build fails with just 'make install'
    # fix for known race condition: https://bugzilla.redhat.com/show_bug.cgi?id=1614502
    system "make", "-j1", "-C", "builder", "index-parse.c"
    system "make", "-C", "builder", "index-scan.c"
    system "make"

    ENV["REALLY_INSTALL"] = "yes"
    system "make", "install"

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
