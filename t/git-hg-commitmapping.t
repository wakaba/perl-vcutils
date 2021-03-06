use strict;
use warnings;
use Path::Class;
use lib file (__FILE__)->dir->parent->subdir ('lib')->stringify;
use Git::Hg::CommitMapping;
use Test::More tests => 1;
use Test::Differences;

my $data_d = file (__FILE__)->dir->subdir ('data', 'git-hg');

my $parsed = Git::Hg::CommitMapping->load_git_hg_mapping ($data_d);
eq_or_diff $parsed, {
   "git2hg" => {
      "366d349721ee7882cefb924cd2e63c5fb6bff04e" => "1c335a8d38afeabb91df90b051444c19c55df597",
      "4fbdbe7aa175ed8a5a62836192efa15340152a90" => "261a4a2a8242ecf3cca0c7798a5d216d43be4743",
      "66aea999b461366558367c25f0b90b2cd29c5c5d" => "bfada9b6c9af6974fe72638591940c3ab17f8477",
      "678f37ab3f2198d839ed14a84ca5c7de680ef4c2" => "bee94450b1694aee03b4d71cad5e197d40781744",
      "67ad0a6b4978570b41e5485177e597e2d7da1237" => "7b597c161f3e13a7b3e76a7bfe354540fe687083",
      "6bf86fd9287ce146f45174ea3bad2658d297f95b" => "0ba24a83967380617af1f129b9327f7868e570a7",
      "7c7d28179be30638098e0f3c6ead6c1c60b5f4f5" => "6be0e0ef3a882cadecb89cdffc09d6e78f3875b2",
      "81b53e53965f1b889cdf2c670abd63d5a89aa4ed" => "effd8b10fac3d0d46ded07906dea9a14f6878181",
      "98f0fd6ab51c1cecaffd5e6933755618c6ea23dc" => "b63a3461c3ec25baf923e877cb2dda2e5cefc7f8",
      "a60b7cc04c6b5ccfa645bba84c3d61aacb4b6154" => "d006922038fad48e57a2b3ab6bc3fdec38bcce57",
      "a62831de0e681d1a19d5061e11595452219564ef" => "4b8dcde512fda9f42eb42242bda57924bf6ab6c4",
      "b1fbdac9c371c828149f37a4b206addd026875d1" => "36c2c1842d05c357b7eaa694da8315194eec70ce",
      "be79d0dd4b3a614e0571ef05029ec829a7c33429" => "6492aa5fdf4e28c4de608ec17728d35a67304f12",
      "c329c2ef8fb2d89234c5ca158f6c54ab4aec66a5" => "7ef5ee3b479526c778f0661ae33209cff664fc21",
      "cb5c47fe06f8da97ccbaf24d525372efa3b8653b" => "d9581e52523d612e6cb965be0ccf8adacfaa5d51",
      "de2154762a9d89671b89fe0b31613995501a4e9d" => "8a3424bbb0cf6dce1699f5ef680f37bd3a834fb6",
      "f22d0fa9d2e4bc02af0b0c2be1d5d6f1b202a727" => "ff6110bf4d82094aff0f69ef0826a2b601e34d97"
   },
   "hg2git" => {
      "0ba24a83967380617af1f129b9327f7868e570a7" => "6bf86fd9287ce146f45174ea3bad2658d297f95b",
      "1c335a8d38afeabb91df90b051444c19c55df597" => "366d349721ee7882cefb924cd2e63c5fb6bff04e",
      "261a4a2a8242ecf3cca0c7798a5d216d43be4743" => "4fbdbe7aa175ed8a5a62836192efa15340152a90",
      "36c2c1842d05c357b7eaa694da8315194eec70ce" => "b1fbdac9c371c828149f37a4b206addd026875d1",
      "4b8dcde512fda9f42eb42242bda57924bf6ab6c4" => "a62831de0e681d1a19d5061e11595452219564ef",
      "6492aa5fdf4e28c4de608ec17728d35a67304f12" => "be79d0dd4b3a614e0571ef05029ec829a7c33429",
      "6be0e0ef3a882cadecb89cdffc09d6e78f3875b2" => "7c7d28179be30638098e0f3c6ead6c1c60b5f4f5",
      "7b597c161f3e13a7b3e76a7bfe354540fe687083" => "67ad0a6b4978570b41e5485177e597e2d7da1237",
      "7ef5ee3b479526c778f0661ae33209cff664fc21" => "c329c2ef8fb2d89234c5ca158f6c54ab4aec66a5",
      "8a3424bbb0cf6dce1699f5ef680f37bd3a834fb6" => "de2154762a9d89671b89fe0b31613995501a4e9d",
      "b63a3461c3ec25baf923e877cb2dda2e5cefc7f8" => "98f0fd6ab51c1cecaffd5e6933755618c6ea23dc",
      "bee94450b1694aee03b4d71cad5e197d40781744" => "678f37ab3f2198d839ed14a84ca5c7de680ef4c2",
      "bfada9b6c9af6974fe72638591940c3ab17f8477" => "66aea999b461366558367c25f0b90b2cd29c5c5d",
      "d006922038fad48e57a2b3ab6bc3fdec38bcce57" => "a60b7cc04c6b5ccfa645bba84c3d61aacb4b6154",
      "d9581e52523d612e6cb965be0ccf8adacfaa5d51" => "cb5c47fe06f8da97ccbaf24d525372efa3b8653b",
      "effd8b10fac3d0d46ded07906dea9a14f6878181" => "81b53e53965f1b889cdf2c670abd63d5a89aa4ed",
      "ff6110bf4d82094aff0f69ef0826a2b601e34d97" => "f22d0fa9d2e4bc02af0b0c2be1d5d6f1b202a727"
   }
};

=head1 LICENSE

Copyright 2012 Wakaba <w@suika.fam.cx>.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
