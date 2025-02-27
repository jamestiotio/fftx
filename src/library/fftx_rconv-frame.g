
##  Copyright (c) 2018-2021, Carnegie Mellon University
##  See LICENSE for details

# 1d and multidimensional complex DFTs

##  Script to generate code, will be driven by a size specification and will write the
##  CUDA/HIP/CPU code to a file.  The code will be compiled into a library for applications
##  to link against -- providing pre-compiled FFTs of standard sizes.

Load(fftx);
ImportAll(fftx);
ImportAll(simt);

##  If the variable createJIT is defined and set true then load the jit module
if ( IsBound(createJIT) and createJIT ) then
    Load(jit);
    Import(jit);
fi;

if codefor = "CUDA" then
    conf := LocalConfig.fftx.confGPU();
elif codefor = "HIP" then
    conf := FFTXGlobals.defaultHIPConf();
elif codefor = "CPU" then
    conf := LocalConfig.fftx.defaultConf();
fi;

if 1 = 1 then
    prefix := "fftx_rconv_";
    jitpref := "cache_rconv_";
    name := prefix::StringInt(szcube[1])::ApplyFunc(ConcatenationString, List(Drop(szcube, 1), s->"x"::StringInt(s)));
    name := name::"_"::codefor;
    jitname := jitpref::StringInt(szcube[1])::ApplyFunc(ConcatenationString, List(Drop(szcube, 1), s->"x"::StringInt(s)));
    jitname := jitname::"_"::codefor::".txt";
    
    PrintLine("fftx_rconv-frame: name = ", name, ", cube = ", szcube, ", jitname = ", jitname, ";\t\t##PICKME##");

    ## This assumes FFTX_COMPLEX_TRUNC_LAST==0
    ##szhalfcube := [Int(szcube[1]/2)+1]::Drop(szcube,1);
    ##  szhalfcube := [szcube[1]/2+1]::Drop(szcube,1);
    ## This assumes FFTX_COMPLEX_TRUNC_LAST==1
    szhalfcube := DropLast(szcube,1)::[Int(Last(szcube)/2)+1];
    ##  szhalfcube := DropLast(szcube,1)::[Last(szcube)/2+1];
    var_1:= var("var_1", BoxND(szhalfcube, TReal));
    var_2:= var("var_2", BoxND(szhalfcube, TReal));
    var_3:= var("var_3", BoxND(szcube, TReal));
    var_4:= var("var_4", BoxND(szcube, TReal));
    var_5:= var("var_5", BoxND(szhalfcube, TReal));
    var_3:= X;
    var_4:= Y;
    symvar := var("sym", TPtr(TReal));
    t := TFCall(TDecl(TDAG([
        TDAGNode(MDPRDFT(szcube,-1), var_1,var_3),
        TDAGNode(Diag(diagTensor(FDataOfs(symvar,Product(szhalfcube),0),fConst(TReal, 2, 1))), var_2,var_1),
        TDAGNode(IMDPRDFT(szcube,1), var_4,var_2),
                  ]),
            [var_1,var_2]
            ),
        rec(fname:=name, params:= [symvar])
    );
    
    opts := conf.getOpts(t);
    if not IsBound ( libdir ) then
        libdir := "srcs";
    fi;

    ##  We need the Spiral functions wrapped in 'extern C' for adding to a library
    opts.wrapCFuncs := true;
    tt := opts.tagIt(t);
    if(IsBound(fftx_includes)) then opts.includes:=fftx_includes; fi;
    c := opts.fftxGen(tt);
    ##  opts.prettyPrint(c);
    PrintTo(libdir::"/"::name::file_suffix, opts.prettyPrint(c));

    ##  If the variable createJIT is defined and set true then output the JIT code to a file
    if ( IsBound(createJIT) and createJIT ) then
	cachedir := GetEnv("FFTX_HOME");
	if (cachedir = "") then cachedir := "../.."; fi;
        cachedir := cachedir::"/cache_jit_files/";
        GASMAN ( "collect" );
        if ( codefor = "HIP" ) then PrintTo ( cachedir::jitname, PrintHIPJIT ( c, opts ) ); fi;
        if ( codefor = "CUDA" ) then PrintTo ( cachedir::jitname, PrintJIT2 ( c, opts ) ); fi;
        if ( codefor = "CPU" ) then PrintTo ( cachedir::jitname, opts.prettyPrint ( c ) ); fi;
    fi;
fi;
