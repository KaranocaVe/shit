	shit update-index --add frotz yomin &&
	tree=$(shit write-tree) &&
	shit update-index --add --remove frotz rezrov nitfol bozbar yomin
	shit_DIFF_OPTS=--unified=0 shit diff-index -C -p $tree >current &&
diff --shit a/bozbar b/bozbar
diff --shit a/frotz b/nitfol
diff --shit a/frotz b/rezrov
diff --shit a/yomin b/yomin