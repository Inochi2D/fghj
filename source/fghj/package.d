/++
$(H2 FGHJ Package)

Publicly imports $(SUBMODULE _fghj), $(SUBMODULE jsonparser), and $(SUBMODULE serialization).

Copyright: Tamedia Digital, 2016

Authors: Ilya Yaroshenko

License: MIT

Macros:
SUBMODULE = $(LINK2 fghj_$1.html, _fghj.$1)
SUBREF = $(LINK2 fghj_$1.html#.$2, $(TT $2))$(NBSP)
T2=$(TR $(TDNW $(LREF $1)) $(TD $+))
T4=$(TR $(TDNW $(LREF $1)) $(TD $2) $(TD $3) $(TD $4))
+/
module fghj;

public import fghj.fghj;
public import fghj.jsonparser;
public import fghj.serialization;
public import fghj.transform;
