class Hivex < Formula
  desc "Self-contained library for reading/writing Windows Registry hive binary files"
  homepage "https://www.libguestfs.org"
  url "https://download.libguestfs.org/hivex/hivex-1.3.18.tar.gz"
  sha256 "8a1e788fd9ea9b6e8a99705ebd0ff8a65b1bdee28e319c89c4a965430d0a7445"

  depends_on "gettext"
  depends_on "readline"

  uses_from_macos "libxml2"

  resource "testhive" do
    url "https://github.com/libguestfs/hivex/raw/1a95c03b5741326128e6c21823ab4f0e363eeb0f/images/special"
    sha256 "cc558c3628f8bf0a69e2c61eb5151492026b6d5041372cc90e20cbb880537271"
  end

  patch do
    url "https://gist.githubusercontent.com/Amar1729/ce54389a5cf9136a3b16472d7b0a4029/raw/aa2db3fc69d9400091952cb972a1d9dd99889b65/enokey.patch"
    sha256 "481a295b1257a33eda1a162d947be7721e5281cecbd3f51bf4ddf5cbbb3ce62d"
  end

  def install
    ENV.prepend_path "PERL5LIB", lib/"perl5"

    args = [
      "--prefix=#{prefix}",
      "--localstatedir=#{var}",
      "--mandir=#{man}",
      "--sysconfdir=#{etc}",
      "--disable-ocaml",
      "--disable-ruby",
      "--disable-perl",
      "--disable-python",
    ]

    # TODO: this works fine on macOS, but on Linux the make process keeps picking up system
    # libxml2 instead of homebrew
    # (the configure script doesn't seem to support any vars/flags for disabling xml support)
    # absolutely disable xml
    inreplace "configure", "have_libxml2=yes", "have_libxml2=no"

    system "./configure", *args

    system "make"
    system "make", "install"
    system "make", "check"

    # TODO: not sure how to fix hivexregedit
    # (bin/"hivexregedit").write_env_script(libexec/"bin/hivexregedit", :PERL5LIB => ENV["PERL5LIB"])
  end

  test do
    # upstream-generated hivefile for testing
    resource("testhive").stage(testpath)

    # hivexget
    assert_equal '"zero"=dword:00000000', shell_output("hivexget #{testpath}/special zero").chomp

    # hivexregedit
    # reg_check = <<~EOS
    #         Windows Registry Editor Version 5.00
    #   #{"      "}
    #         [\zerokey]
    #         "zeroval"=dword:00000000
    # EOS
    # reg_output = shell_output("hivexregedit --export #{testpath}/special zero", 0).chomp
    # assert_equal reg_check reg_output

    # hivexsh
    (testpath/"test.sh").write <<~EOS
      #/usr/local/bin/hivexsh -f
      load #{testpath}/special
      cd zero
      lsval
      quit
    EOS
    assert_equal '"zero"=dword:00000000', shell_output("#{bin}/hivexsh -f test.sh").chomp
  end
end
