### ATTEMPT TO "EXTRACT" DICE DAMAGE FUNCTION

using Mimi
using XLSX: readxlsx

include("src/helpers.jl")
include("src/parameters.jl")

include("src/marginaldamage.jl")

include("src/components/damages_component.jl")
include("src/components/neteconomy_component.jl")
include("src/components/welfare_component.jl")

# include("helpers.jl")
# include("parameters.jl")

# include("marginaldamage.jl")

# include("components/damages_component.jl")
# include("components/neteconomy_component.jl")
# include("components/welfare_component.jl")

# export constructdice, getdiceexcel

const model_years = 2015:5:2510

m = Model()
set_dimension!(m, :time, model_years)

#--------------------------------------------------------------------------
# Add components in order
#--------------------------------------------------------------------------

add_comp!(m, damages, :damages)
add_comp!(m, neteconomy, :neteconomy)
add_comp!(m, welfare, :welfare)

#--------------------------------------------------------------------------
# Make internal parameter connections
#--------------------------------------------------------------------------
    
# Damages
# connect_param!(m, :damages, :TATM, :climatedynamics, :TATM) # need to connect to external temp change from FAIR
# MimiDICE2016.connect_param!(m, :damages, :YGROSS, :grosseconomy, :YGROSS)
# connect_param!(m, :neteconomy, :YGROSS, :grosseconomy, :YGROSS)
connect_param!(m, :neteconomy, :DAMAGES, :damages, :DAMAGES)
# connect_param!(m, :neteconomy, :SIGMA, :emissions, :SIGMA)
connect_param!(m, :welfare, :CPC, :neteconomy, :CPC)

#--------------------------------------------------------------------------
# Set external parameter values 
#--------------------------------------------------------------------------

# load parameters
# datafile = joinpath(dirname(@__FILE__), "..", "data", "DICE2016R-090916ap-v2.xlsm")
datafile = joinpath(dirname(@__FILE__), "data", "DICE2016R-090916ap-v2.xlsm")
params = MimiDICE2016.getdicefairexcelparameters(datafile)

# m = constructdice(params)

for (name, value) in params
    set_param!(m, name, value)
end
    
return m

# doesn't work -- need YGROSS, SIGMA, TATM from other parts of model
