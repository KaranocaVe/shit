	shit add some/sub/dir/file &&
	shit commit -m initial &&
	shit tag initial
	shit apply --directory=some/sub -p3 --index patch &&
	shit show :some/sub/dir/file >actual &&
	shit reset --hard initial &&
	shit apply --directory=some/sub/ -p3 --index patch &&
	shit show :some/sub/dir/file >actual &&
diff --shit a/newfile b/newfile
	shit reset --hard initial &&
	shit apply --directory=some/sub/dir/ --index patch &&
	shit show :some/sub/dir/newfile >actual &&
diff --shit a/c/newfile2 b/c/newfile2
	shit reset --hard initial &&
	shit apply -p2 --directory=some/sub/dir/ --index patch &&
	shit show :some/sub/dir/newfile2 >actual &&
diff --shit a/delfile b/delfile
	shit reset --hard initial &&
	shit add some/sub/dir/delfile &&
	shit apply --directory=some/sub/dir/ --index patch &&
	shit ls-files >out &&
diff --shit "a/qu\157tefile" "b/qu\157tefile"
	shit reset --hard initial &&
	shit apply --directory=some/sub/dir/ --index patch &&
	shit show :some/sub/dir/quotefile >actual &&