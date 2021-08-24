#--------------------------------------------------------------------------
# RUN DICE2016 DAMAGE FUNCTION WITH SSPS -- OLD
#--------------------------------------------------------------------------

using Pkg
Pkg.activate("development")
using Revise, Mimi, MimiDICE2016, MimiFAIR, XLSX, Plots, DataFrames # make sure MimiFAIR is on the master branch

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
# add components in order
#--------------------------------------------------------------------------

add_comp!(m, damages, :damages)
add_comp!(m, neteconomy, :neteconomy)
add_comp!(m, welfare, :welfare)

#--------------------------------------------------------------------------
# make internal parameter connections
#--------------------------------------------------------------------------

# Damages
# connect_param!(m, :damages, :TATM, :climatedynamics, :TATM) # need to connect to external temp change from FAIR
# MimiDICE2016.connect_param!(m, :damages, :YGROSS, :grosseconomy, :YGROSS)
# connect_param!(m, :neteconomy, :YGROSS, :grosseconomy, :YGROSS)
connect_param!(m, :neteconomy, :DAMAGES, :damages, :DAMAGES)
# connect_param!(m, :neteconomy, :SIGMA, :emissions, :SIGMA)
connect_param!(m, :welfare, :CPC, :neteconomy, :CPC)

#--------------------------------------------------------------------------
# set external parameter values 
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

# run(m)
# ERROR: Cannot build model; the following parameters are not set:
#   TATM
#   YGROSS
#   SIGMA
#   YGROSS

## set SIGMA from native DICE2016
DICE2016 = MimiDICE2016.get_model()
run(DICE2016)

DICE2016[:emissions, :SIGMA]
MimiDICE2016.set_param!(m, :SIGMA, DICE2016[:emissions, :SIGMA])

# # extract TATM from native DICE2016 base model
# DICE2016[:damages, :TATM]
# # set parameter
# MimiDICE2016.set_param!(m, :TATM, DICE2016[:damages, :TATM])

# extract TATM from native FAIR base model
FAIR = MimiFAIR.get_model()
run(FAIR)
fair_years = collect(1765:1:2500)
fair_temperature = FAIR[:temperature, :T]

temperature_df = DataFrame(year = fair_years, T = fair_temperature)

fair_input_temp = temperature_df[[year in model_years for year in fair_years], :T] # 58 element array, needs to be 100. make temperature constant after 2300
append!(fair_input_temp, repeat([fair_input_temp[end]], length(model_years) - length(fair_input_temp)))

# set parameter
MimiDICE2016.set_param!(m, :TATM, fair_input_temp)

## set YGROSS

DICE2016[:neteconomy, :YGROSS] # 100 element array

# read in SSP data
ssp_gdp_file_path = "data/ssps_gdp.xlsx"
ssp_gdp_data = XLSX.readdata(ssp_gdp_file_path, "data", "G2:X6") # units billion US$2005/yr (PPP), 2015 to 2100

# extend to 2510 (currently only to 2100) -- assume constant after 2100
ssp_gdp_data_extended = ssp_gdp_data
for i in 1:(length(model_years) - size(ssp_gdp_data)[2])
    ssp_gdp_data_extended = hcat(ssp_gdp_data_extended, ssp_gdp_data[:,end])
end
ssp_gdp_data_extended

# inflate from 2005 to 2010 USD
inflation_factor = 92.9/81.5 # check this -- using charles' world GDP spreadsheet for now
ssp_gdp_inflated = convert(Array{Float64}, ssp_gdp_data_extended) .* inflation_factor ./ 1e3 # inflate and convert to trillions

ssp_gdp_dict = Dict("SSP1" => ssp_gdp_inflated[1,:],
                "SSP2" => ssp_gdp_inflated[2,:],
                "SSP3" => ssp_gdp_inflated[3,:],
                "SSP4" => ssp_gdp_inflated[4,:],
                "SSP5" => ssp_gdp_inflated[5,:])

input_gdp = ssp_gdp_dict["SSP2"]

# set param
MimiDICE2016.set_param!(m, :YGROSS, input_gdp)

#--------------------------------------------------------------------------
# run damage function (base model)
#--------------------------------------------------------------------------

run(m)

m[:neteconomy, :C]
DICE2016[:neteconomy, :C]

using Plots

plot(model_years[1:18], DICE2016[:neteconomy, :C][1:18], label = "Native DICE2016", legend = :bottomright)
plot!(model_years[1:18], m[:neteconomy, :C][1:18], label = "DICE2016 x SSP1")
plot!(model_years[1:18], m[:neteconomy, :C][1:18], label = "DICE2016 x SSP2")

#--------------------------------------------------------------------------
# repeat for marginal model
#--------------------------------------------------------------------------

mm = Model()
set_dimension!(mm, :time, model_years)

add_comp!(mm, damages, :damages)
add_comp!(mm, neteconomy, :neteconomy)
add_comp!(mm, welfare, :welfare)

connect_param!(mm, :neteconomy, :DAMAGES, :damages, :DAMAGES)
connect_param!(mm, :welfare, :CPC, :neteconomy, :CPC)

for (name, value) in params
    set_param!(mm, name, value)
end

# set SIGMA from native DICE2016
MimiDICE2016.set_param!(mm, :SIGMA, DICE2016[:emissions, :SIGMA])

# extract TATM from native FAIR perturbed model
pulse_year = 2030
perturbed_fair_temperature = MimiFAIR.get_perturbed_fair_temperature(pulse_year = pulse_year)

new_temperature_df = DataFrame(year = fair_years, T = perturbed_fair_temperature)

new_fair_input_temp = temperature_df[[year in model_years for year in fair_years], :T] # 58 element array, needs to be 100. make temperature constant after 2300
append!(new_fair_input_temp, repeat([new_fair_input_temp[end]], length(model_years) - length(new_fair_input_temp)))

# set parameter
MimiDICE2016.set_param!(mm, :TATM, new_fair_input_temp)

## set YGROSS
# input_gdp = ssp_gdp_dict["SSP2"]

# set param
MimiDICE2016.set_param!(mm, :YGROSS, input_gdp)

run(mm)


#--------------------------------------------------------------------------
# compare
#--------------------------------------------------------------------------

plot(model_years, m[:neteconomy, :C])
plot!(model_years, mm[:neteconomy, :C])

plot(model_years, m[:neteconomy, :C] .- mm[:neteconomy, :C])


plot(model_years[1:18], m[:neteconomy, :C][1:18])
plot!(model_years[1:18], DICE2016[:neteconomy, :C][1:18])


plot!(model_years, mm[:damages, :TATM])

m[:damages, :TATM] .- mm[:damages, :TATM]