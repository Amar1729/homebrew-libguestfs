# Amar1729 Libguestfs

https://libguestfs.org/

Monsters be here: formulae in this tap are deprecated, as they don't build on macOS anymore. Good luck if you need libguestfs on macOS D:

----

## How do I install these formulae?

`brew install amar1729/libguestfs/<formula>`

Or `brew tap amar1729/libguestfs` and then `brew install <formula>`.

### Versions

#### `libguestfs@1.32`

Old release of libguestfs. This tap will try to provide bottles for 1.32 but may not stay up to date. If there aren't available bottles, you can build from source. However, there are a few build dependencies that conflict with common formulae you might have installed on your system. The easiest way to solve this is to unlink the up-to-date formulae, install this formula from source, and then remove build dependencies once you are done:

```bash
$ brew unlink coreutils # conflicts with our build dependency `truncate`
$ brew unlink automake # conflicts with our build dep automake-1.15

# -v is verbose, -s is build from source
$ brew install -v -s amar1729/libguestfs/libguestfs@1.32

# once build is complete, test to make sure it's ok
$ brew test -v amar1729/libguestfs/libguestfs@1.32

# safely remove build dependencies
$ brew uninstall automake-1.15 truncate
$ brew link automake
$ brew link coreutils
```

## Documentation

`brew help`, `man brew` or check [Homebrew's documentation](https://docs.brew.sh).

## History

Originally based off of work done [zchee's homebrew tap](https://github.com/zchee/homebrew-libguestfs).
That tap has only been updated to support `libguestfs 1.30` (current version as of spring 2021 is 1.40).

Building libguestfs inside Homebrew is a bit of a pain, due to differences in the macOS build as well as certain homebrew restrictions over time (e.g. removing the `osxfuse` formula in early 2021) so this tap will try to include previous versions of libguestfs as well as the current version (as `libguestfs.rb`).

other work:
https://listman.redhat.com/archives/libguestfs/2015-February/msg00040.html
