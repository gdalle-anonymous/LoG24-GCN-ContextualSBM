using Aqua
using JuliaFormatter
using JET
using Oversmoothing
using Test

@testset verbose = true "Oversmoothing.jl" begin
    @testset "Formalities" begin
        @testset "Aqua" begin
            Aqua.test_all(Oversmoothing; ambiguities=false, deps_compat=false)
        end
        @testset "JuliaFormatter" begin
            @test JuliaFormatter.format(Oversmoothing, overwrite=true)
        end
        @testset "JET" begin
            JET.test_package(Oversmoothing; target_defined_modules=true)
        end
    end
    @testset "Stochastic Block Model" begin
        include("stochastic_block_model.jl")
    end
    @testset "Mixture" begin
        include("mixture.jl")
    end
    @testset "State evolution" begin
        include("state_evolution.jl")
    end
    @testset "Kullback-Leibler divergence" begin
        include("kullback_leibler.jl")
    end
end
