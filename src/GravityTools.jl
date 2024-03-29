module GravityTools

# Required libraries
using Distributions
using Measurements
using Distributed
using ProgressMeter

# Utility methods and functions
include("Utils.jl")

# Abstract Framework definitions
include("Frameworks.jl")

# Physics related methods and definitions
include("Physics.jl")

# Astrophysical Objects related methods and definitions
include("AstrophysicalObjects.jl")

export BinarySystem, PSRBinarySystem

# Astrophysical Framework methods and definitions
include("AstrophysicalFramework.jl")

include("TempoFramework.jl")

export TempoParameter, get_TempoParameter, update_pf_theory!, modify_par_file, run_tempo, get_par_file_work, read_params

#export FullUnit, DiffUnit, ContourUnit, DiffContourUnit, RefinementSettings, Refinement2DGrid, precalculate_2DGrid, refine_2DGrid, calculate_2DGrid


# Export important types, functions, and abstract types
export DEF, GR, SimpleEOS, TabularKernel, Physics, StellarObject, AstrophysicalFramework, simulate!, calculate!, update_framework!, input_parameters
export get_inputpool


# Export abstract types separately
export AbstractStellarObject, AbstractStellarObjectQuantities
export AbstractAstrophysicalObject, AbstractAstrophysicalObjectQuantities, AbstractDoubleStellarObjectQuantities

# Mathematical constants and variables
export lvl_1σ, lvl_2σ, lvl_3σ, lvl_4σ, lvl_5σ, lvl_6σ, lvl_7σ, lvl_68CL, lvl_90CL, lvl_95CL, lvl_99CL
export LinRule, LogRule, RangeVariable, ValueVariable, Variable, Var

end # module
