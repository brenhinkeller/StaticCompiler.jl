
@testset "Cosmopolitan Executable Integration" begin
    # Setup
    testpath = pwd()
    scratch = joinpath(tempdir(), "scratch")
    mkpath(scratch)
    cd(scratch)
    jlpath = joinpath(Sys.BINDIR, Base.julia_exename()) # Get path to julia executable

    ## --- Times table, file IO, mallocarray
    let
        # Attempt to compile
        # We have to start a new Julia process to get around the fact that Pkg.test
        # disables `@inbounds`, but ironically we can use `--compile=min` to make that
        # faster.
        status = -1
        try
            isfile("times_table") && rm("times_table")
            status = run(`$jlpath --startup=no --compile=min $testpath/cosmopolitan_scripts/times_table.jl`)
        catch e
            @warn "Could not compile $testpath/cosmopolitan_scripts/times_table.jl"
            println(e)
        end
        @test isa(status, Base.Process)
        @test isa(status, Base.Process) && status.exitcode == 0

        # Attempt to run
        println("5x5 times table:")
        status = -1
        try
            StaticTools.system(c"ls -alh")
            status = StaticTools.system(c"bash ./times_table.com 5 5")
        catch e
            @warn "Could not run $(scratch)/times_table.com"
            println(e)
        end
        @test status === Int32(0)
        # Test ascii output
        @test parsedlm(Int, c"table.tsv", '\t') == (1:5)*(1:5)'
        # Test binary output
        @test fread!(szeros(Int, 5,5), c"table.b") == (1:5)*(1:5)'
    end

    ## --- "withmallocarray"-type do-block pattern
    let
        # Compile...
        status = -1
        try
            isfile("withmallocarray") && rm("withmallocarray")
            status = run(`$jlpath --startup=no --compile=min $testpath/cosmopolitan_scripts/withmallocarray.jl`)
        catch e
            @warn "Could not compile $testpath/cosmopolitan_scripts/withmallocarray.jl"
            println(e)
        end
        @test isa(status, Base.Process)
        @test isa(status, Base.Process) && status.exitcode == 0

        # Run...
        println("3x3 malloc arrays via do-block syntax:")
        status = -1
        try
            StaticTools.system(c"ls -alh")
            status = StaticTools.system(c"bash ./withmallocarray.com 3 3")
        catch e
            @warn "Could not run $(scratch)/withmallocarray.com"
            println(e)
        end
        @test status === Int32(0)
    end

    ## --- Random number generation
    let
        # Compile...
        status = -1
        try
            isfile("rand_matrix") && rm("rand_matrix")
            status = run(`$jlpath --startup=no --compile=min $testpath/cosmopolitan_scripts/rand_matrix.jl`)
        catch e
            @warn "Could not compile $testpath/cosmopolitan_scripts/rand_matrix.jl"
            println(e)
        end
        @test isa(status, Base.Process)
        @test isa(status, Base.Process) && status.exitcode == 0

        # Run...
        println("5x5 uniform random matrix:")
        status = -1
        try
            StaticTools.system(c"ls -alh")
            status = StaticTools.system(c"bash ./rand_matrix.com 5 5")
        catch e
            @warn "Could not run $(scratch)/rand_matrix.com"
            println(e)
        end
        @test status === Int32(0)
    end

    let
        # Compile...
        status = -1
        try
            isfile("randn_matrix") && rm("randn_matrix")
            status = run(`$jlpath --startup=no --compile=min $testpath/cosmopolitan_scripts/randn_matrix.jl`)
        catch e
            @warn "Could not compile $testpath/cosmopolitan_scripts/randn_matrix.jl"
            println(e)
        end
        @static if Sys.isbsd()
            @test isa(status, Base.Process)
            @test isa(status, Base.Process) && status.exitcode == 0
        end

        # Run...
        println("5x5 Normal random matrix:")
        status = -1
        try
            StaticTools.system(c"ls -alh")
            status = StaticTools.system(c"bash ./randn_matrix.com 5 5")
        catch e
            @warn "Could not run $(scratch)/randn_matrix.com"
            println(e)
        end
        @static if Sys.isbsd()
            @test status === Int32(0)
        end
    end

    ## --- Test LoopVectorization integration
    @static if LoopVectorization.VectorizationBase.has_feature(Val{:x86_64_avx2})
        let
            # Compile...
            status = -1
            try
                isfile("loopvec_product") && rm("loopvec_product")
                status = run(`$jlpath --startup=no --compile=min $testpath/cosmopolitan_scripts/loopvec_product.jl`)
            catch e
                @warn "Could not compile $testpath/cosmopolitan_scripts/loopvec_product.jl"
                println(e)
            end
            @test isa(status, Base.Process)
            @test isa(status, Base.Process) && status.exitcode == 0

            # Run...
            println("10x10 table sum:")
            status = -1
            try
                StaticTools.system(c"ls -alh")
            status = StaticTools.system(c"bash ./loopvec_product.com 10 10")
            catch e
                @warn "Could not run $(scratch)/loopvec_product.com"
                println(e)
            end
            @test status === Int32(0)
            @test parsedlm(c"product.tsv",'\t')[] == 3025 skip=true
        end
    end

    let
        # Compile...
        status = -1
        try
            isfile("loopvec_matrix") && rm("loopvec_matrix")
            status = run(`$jlpath --startup=no --compile=min $testpath/cosmopolitan_scripts/loopvec_matrix.jl`)
        catch e
            @warn "Could not compile $testpath/cosmopolitan_scripts/loopvec_matrix.jl"
            println(e)
        end
        @test isa(status, Base.Process)
        @test isa(status, Base.Process) && status.exitcode == 0

        # Run...
        println("10x5 matrix product:")
        status = -1
        try
            StaticTools.system(c"ls -alh")
            status = StaticTools.system(c"bash ./loopvec_matrix.com 10 5")
        catch e
            @warn "Could not run $(scratch)/loopvec_matrix.com"
            println(e)
        end
        @test status === Int32(0)
        A = (1:10) * (1:5)'
        # Check ascii output
        @test parsedlm(c"table.tsv",'\t') == A' * A skip=true
        # Check binary output
        @test fread!(szeros(5,5), c"table.b") == A' * A skip=true
    end

    let
        # Compile...
        status = -1
        try
            isfile("loopvec_matrix_stack") && rm("loopvec_matrix_stack")
            status = run(`$jlpath --startup=no --compile=min $testpath/cosmopolitan_scripts/loopvec_matrix_stack.jl`)
        catch e
            @warn "Could not compile $testpath/cosmopolitan_scripts/loopvec_matrix_stack.jl"
            println(e)
        end
        @test isa(status, Base.Process)
        @test isa(status, Base.Process) && status.exitcode == 0

        # Run...
        println("10x5 matrix product:")
        status = -1
        try
            StaticTools.system(c"ls -alh")
            status = StaticTools.system(c"bash ./loopvec_matrix_stack.com")
        catch e
            @warn "Could not run $(scratch)/loopvec_matrix_stack.com"
            println(e)
        end
        @test status === Int32(0)
        A = (1:10) * (1:5)'
        @test parsedlm(c"table.tsv",'\t') == A' * A skip=true
    end


    ## --- Test string handling

    let
        # Compile...
        status = -1
        try
            isfile("print_args") && rm("print_args")
            status = run(`$jlpath --startup=no --compile=min $testpath/cosmopolitan_scripts/print_args.jl`)
        catch e
            @warn "Could not compile $testpath/cosmopolitan_scripts/print_args.jl"
            println(e)
        end
        @test isa(status, Base.Process)
        @test isa(status, Base.Process) && status.exitcode == 0

        # Run...
        println("String indexing and handling:")
        status = -1
        try
            StaticTools.system(c"ls -alh")
            status = StaticTools.system(c"bash ./print_args.com foo bar")
        catch e
            @warn "Could not run $(scratch)/print_args.com"
            println(e)
        end
        @test status === Int32(0)
    end

    ## --- Test interop

    @static if Sys.isbsd()
    let
        # Compile...
        status = -1
        try
            isfile("interop") && rm("interop")
            status = run(`$jlpath --startup=no --compile=min $testpath/cosmopolitan_scripts/interop.jl`)
        catch e
            @warn "Could not compile $testpath/cosmopolitan_scripts/interop.jl"
            println(e)
        end
        @test isa(status, Base.Process)
        @test isa(status, Base.Process) && status.exitcode == 0

        # Run...
        println("Interop:")
        status = -1
        try
            StaticTools.system(c"ls -alh")
            status = StaticTools.system(c"bash ./interop.com")
        catch e
            @warn "Could not run $(scratch)/interop.com"
            println(e)
        end
        @test status === Int32(0)
    end
    end

    ## --- Clean up
    cd(testpath)
    rm(scratch; recursive=true)

end
