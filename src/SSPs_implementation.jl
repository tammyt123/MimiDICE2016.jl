#--------------------------------------------------------------------------
# RUN DICE2016 WITH SSPS (REPLACE EMISSIONS AND YGROSS)
#--------------------------------------------------------------------------

using Pkg
Pkg.activate("development")
using Revise, Mimi, MimiDICE2016, XLSX, Plots, DataFrames 
# using MimiFAIR # make sure MimiFAIR is on the master branch

#--------------------------------------------------------------------------
# replace YGROSS with SSP GDP
#--------------------------------------------------------------------------

# get model
m = MimiDICE2016.get_model()
const model_years = 2015:5:2510

# read in SSP GDP data
ssp_gdp_file_path = "data/ssps_gdp.xlsx"
ssp_gdp_data = XLSX.readdata(ssp_gdp_file_path, "data", "G2:X6") # units billion US$2005/yr (PPP), 2015 to 2100

# extend to 2510 (currently only to 2100) -- assume constant after 2100
ssp_gdp_data_extended = ssp_gdp_data
for i in 1:(length(model_years) - size(ssp_gdp_data)[2])
    ssp_gdp_data_extended = hcat(ssp_gdp_data_extended, ssp_gdp_data[:,end])
end
# ssp_gdp_data_extended

# inflate from 2005 to 2010 USD
inflation_factor = 92.9/81.5 # check this -- using charles' world GDP spreadsheet for now
ssp_gdp_inflated = convert(Array{Float64}, ssp_gdp_data_extended) .* inflation_factor ./ 1e3 # inflate and convert to trillions

ssp_gdp_dict = Dict("SSP1" => ssp_gdp_inflated[1,:],
                "SSP2" => ssp_gdp_inflated[2,:],
                "SSP3" => ssp_gdp_inflated[3,:],
                "SSP4" => ssp_gdp_inflated[4,:],
                "SSP5" => ssp_gdp_inflated[5,:])

input_gdp = ssp_gdp_dict["SSP5"]

# set param
MimiDICE2016.set_param!(m, :YGROSS, input_gdp)

#--------------------------------------------------------------------------
# replace E with SSP CO2 emissions
#--------------------------------------------------------------------------

# read in SSP CO2 emissions data
ssp_co2_emissions_file_path = "data/ssps_co2_emissions_total.xlsx"
ssp_co2_emissions_data = XLSX.readdata(ssp_co2_emissions_file_path, "data", "F2:O10") # units billion US$2005/yr (PPP), 2015 to 2100

# extend to 2510 (currently only to 2100) -- assume constant after 2100
ssp_co2_emissions_data_extended = ssp_co2_emissions_data
for i in 1:(length(model_years) - size(ssp_co2_emissions_data)[2])
    ssp_co2_emissions_data_extended = hcat(ssp_co2_emissions_data_extended, ssp_co2_emissions_data[:,end])
end
ssp_co2_emissions_data_extended

ssp_co2_emissions_dict = Dict("SSP3-70" => ssp_co2_emissions_data_extended[1,:],
                "SSP3-LowNTCF" => ssp_co2_emissions_data_extended[2,:],
                "SSP4-34" => ssp_co2_emissions_data_extended[3,:],
                "SSP4-60" => ssp_co2_emissions_data_extended[4,:],
                "SSP1-19" => ssp_co2_emissions_data_extended[5,:],
                "SSP1-26" => ssp_co2_emissions_data_extended[6,:],
                "SSP2-45" => ssp_co2_emissions_data_extended[7,:],
                "SSP5-34-OS" => ssp_co2_emissions_data_extended[8,:],
                "SSP5-85" => ssp_co2_emissions_data_extended[9,:])

input_co2_emissions = ssp_co2_emissions_dict["SSP5-85"] ./ 1e3 # convert to GtCO2

# set param
MimiDICE2016.set_param!(m, :E, input_co2_emissions)

#--------------------------------------------------------------------------
# run and compare to native DICE2016
#--------------------------------------------------------------------------

run(m)

DICE2016 = MimiDICE2016.get_model()
run(DICE2016)

# temperature
plot(model_years, m[:damages, :TATM], title = "Temperature", label = "SSP5 x DICE2016", legend = :bottomright)
plot!(model_years, DICE2016[:damages, :TATM], label = "Native DICE2016")

# YGROSS
plot(model_years, m[:neteconomy, :YGROSS], title = "YGROSS", label = "SSP5 x DICE2016", legend = :topleft)
plot!(model_years, DICE2016[:neteconomy, :YGROSS], label = "Native DICE2016")

# emissions
plot(model_years, m[:co2cycle, :E], title = "CO2 Emissions", label = "SSP5 x DICE2016", legend = :topright)
plot!(model_years, DICE2016[:co2cycle, :E], label = "Native DICE2016")

# # damages (note: this is just a fraction of YGROSS)
# plot(model_years, m[:damages, :DAMAGES], title = "Damages", label = "SSP5 x DICE2016", legend = :topleft)
# plot!(model_years, DICE2016[:damages, :DAMAGES], label = "Native DICE2016")

# consumption
plot(model_years, m[:neteconomy, :C], title = "Consumption", label = "SSP5 x DICE2016", legend = :topleft)
plot!(model_years, DICE2016[:neteconomy, :C], label = "Native DICE2016")



plot(model_years, m[:grosseconomy, :YGROSS], title = "YGROSS", label = ":grosseconomy", legend = :bottomright)
plot!(model_years, m[:neteconomy, :YGROSS], label = ":neteconomy")
plot!(model_years, m[:damages, :YGROSS], label = ":damages")