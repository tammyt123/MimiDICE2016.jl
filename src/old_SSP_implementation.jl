#--------------------------------------------------------------------------
# RUN DICE2016 WITH SSPS (REPLACE EMISSIONS AND YGROSS)
#--------------------------------------------------------------------------

using Pkg
Pkg.activate("development")
using Revise, Mimi, MimiDICE2016, XLSX, Plots, DataFrames, MimiIWG
# using MimiFAIR # make sure MimiFAIR is on the master branch

#--------------------------------------------------------------------------
# replace YGROSS with SSP GDP
#--------------------------------------------------------------------------

## get model
m = MimiDICE2016.get_model()
run(m)
const model_years = 2015:5:2510

## read in SSP GDP data
ssp_gdp_file_path = "data/ssps_gdp.xlsx"
ssp_gdp_data = XLSX.readdata(ssp_gdp_file_path, "data", "G2:X6") # units billion US$2005/yr (PPP), 2015 to 2100

## extend to 2510 (currently only to 2100)

# assuming constant after 2100
# ssp_gdp_data_extended = ssp_gdp_data
# for i in 1:(length(model_years) - size(ssp_gdp_data)[2])
#     ssp_gdp_data_extended = hcat(ssp_gdp_data_extended, ssp_gdp_data[:,end])
# end
# # ssp_gdp_data_extended

# # growing everything at 2% post 2100
# ssp_gdp_data_extended = ssp_gdp_data
# for i in 1:(length(model_years) - size(ssp_gdp_data)[2])
#     ssp_gdp_data_extended = hcat(ssp_gdp_data_extended, (ssp_gdp_data_extended[:,end] .* 1.02))
# end
# ssp_gdp_data_extended

# # growing everything at growth rate in last period for post-2100
# ssp_gdp_data_extended = ssp_gdp_data
# ssp_gdp_2100_grw = (ssp_gdp_data[:,end] ./ ssp_gdp_data[:,end-1]) # 5 yr growth rate
# for i in 1:(length(model_years) - size(ssp_gdp_data)[2])
#     ssp_gdp_data_extended = hcat(ssp_gdp_data_extended, (ssp_gdp_data_extended[:,end] .* ssp_gdp_2100_grw))
# end
# ssp_gdp_data_extended

# growing everything at growth rate in last period for 2100 to 2300, constant after 2300
ssp_gdp_data_extended = ssp_gdp_data
ssp_gdp_2100_grw = (ssp_gdp_data[:,end] ./ ssp_gdp_data[:,end-1]) # 5 yr growth rate
for i in 1:(length(model_years) - size(ssp_gdp_data)[2])
    if i < 40
        ssp_gdp_data_extended = hcat(ssp_gdp_data_extended, (ssp_gdp_data_extended[:,end] .* ssp_gdp_2100_grw))
    else
        ssp_gdp_data_extended = hcat(ssp_gdp_data_extended, (ssp_gdp_data_extended[:,end]))
    end
end
ssp_gdp_data_extended

average_ssp = (sum(ssp_gdp_data_extended, dims = 1) ./ 5)'

plot(model_years, ssp_gdp_data_extended[1,:], label = "SSP1")
plot!(model_years, ssp_gdp_data_extended[2,:], label = "SSP2")
plot!(model_years, ssp_gdp_data_extended[3,:], label = "SSP3")
plot!(model_years, ssp_gdp_data_extended[4,:], label = "SSP4")
plot!(model_years, ssp_gdp_data_extended[5,:], label = "SSP5")
plot!(model_years, average_ssp, label = "Average of SSPs")
plot!(model_years, m[:grosseconomy, :YGROSS] .* 1e3, label = "Native DICE2016")

## inflate from 2005 to 2010 USD
inflation_factor = 92.9/81.5 # check this -- using charles' world GDP spreadsheet for now
ssp_gdp_inflated = convert(Array{Float64}, ssp_gdp_data_extended) .* inflation_factor ./ 1e3 # inflate and convert to trillions

ssp_gdp_dict = Dict("SSP1" => ssp_gdp_inflated[1,:],
                "SSP2" => ssp_gdp_inflated[2,:],
                "SSP3" => ssp_gdp_inflated[3,:],
                "SSP4" => ssp_gdp_inflated[4,:],
                "SSP5" => ssp_gdp_inflated[5,:])

input_gdp = ssp_gdp_dict["SSP3"]

## set param
MimiDICE2016.set_param!(m, :YGROSS, input_gdp)

#--------------------------------------------------------------------------
# replace E with SSP CO2 emissions
#--------------------------------------------------------------------------

## read in SSP CO2 emissions data
ssp_co2_emissions_file_path = "data/ssps_co2_emissions_total.xlsx"
ssp_co2_emissions_data = XLSX.readdata(ssp_co2_emissions_file_path, "data", "F2:O10") # units billion US$2005/yr (PPP), 2015 to 2100

## extend to 2510 (currently only to 2100)
# # assume constant after 2100
# ssp_co2_emissions_data_extended = ssp_co2_emissions_data
# for i in 1:(length(model_years) - size(ssp_co2_emissions_data)[2])
#     ssp_co2_emissions_data_extended = hcat(ssp_co2_emissions_data_extended, ssp_co2_emissions_data_extended[:,end])
# end
# ssp_co2_emissions_data_extended

# decline at constant 2% post-2100
ssp_co2_emissions_data_extended = ssp_co2_emissions_data
for i in 1:(length(model_years) - size(ssp_co2_emissions_data)[2])
    ssp_co2_emissions_data_extended = hcat(ssp_co2_emissions_data_extended, ssp_co2_emissions_data_extended[:,end] * 0.98)
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

input_co2_emissions = ssp_co2_emissions_dict["SSP3-70"] ./ 1e3 # convert to GtCO2

## set param
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


# plot(model_years, m[:grosseconomy, :YGROSS], title = "YGROSS", label = ":grosseconomy", legend = :bottomright)
# plot!(model_years, m[:neteconomy, :YGROSS], label = ":neteconomy")
# plot!(model_years, m[:damages, :YGROSS], label = ":damages")

#--------------------------------------------------------------------------
# create marginal model
#--------------------------------------------------------------------------

mm = MimiDICE2016.get_model()

MimiDICE2016.set_param!(mm, :YGROSS, input_gdp)
MimiDICE2016.set_param!(mm, :E, input_co2_emissions)

run(mm)

mm[:co2cycle, :E]
m[:co2cycle, :E]

# add_comp!(mm, Mimi.adder, :marginalemission, before=:co2cycle)

year = 2030
year_index = findfirst(isequal(year), model_years)

# addem = zeros(length(model_years))
# addem[year_index] = 1.0

# set_param!(mm, :marginalemission, :add, addem)
# connect_param!(mm, :marginalemission, :input, :emissions, :E)
# connect_param!(mm, :co2cycle, :E, :marginalemission, :output)

new_emissions = mm[:co2cycle, :E]
new_emissions[year_index] =  mm[:co2cycle, :E][year_index] + 1.0
MimiDICE2016.set_param!(mm, :E, new_emissions)
run(mm)

# mm[:co2cycle, :E] .- m[:co2cycle, :E]

marginal_damages = (m[:neteconomy, :C] .- mm[:neteconomy, :C]) * 1e3

# plot(model_years, m[:neteconomy, :C], title = "Consumption", label = "Base", legend = :topleft)
# plot!(model_years, mm[:neteconomy, :C], label = "Marginal")

# plot(model_years, marginal_damages, title = "Marginal Damages", label = "SSPs", legend = :bottomright)
# plot!(model_years, marginal_damages, label = "Native DICE2016")

# plot(model_years, m[:co2cycle, :E], title = "Emissions", label = "Base", legend = :topright)
# plot!(model_years, mm[:co2cycle, :E], label = "Marginal")



prtp = 0.03
eta = 0.0

annual_years = collect(2015:1:2510)

md_interp = MimiIWG._interpolate(marginal_damages, model_years, annual_years)

# constant discounting for now
df = zeros(length(annual_years))
for i in 1:length(annual_years)
    if i >= year_index
        df[i] = 1/(1+prtp)^(i-year_index)
    end
end

scc = sum(df .* md_interp) 

## compare to DICE2016
DICE2016_mm = MimiDICE2016.get_marginal_model(year = 2030)
run(DICE2016_mm)
DICE2016_mm[:neteconomy, :C]

marginal_damages_native = DICE2016_mm[:neteconomy, :C] * -1 * 1e12

plot(model_years, marginal_damages)
plot!(model_years, marginal_damages_native)

# sum(marginal_damages)


## to 2100 only
annual_years = collect(2015:1:2100)

md_interp_ssps = MimiIWG._interpolate(marginal_damages, model_years, annual_years)

df = zeros(length(annual_years))
for i in 1:length(annual_years)
    if i >= year_index
        df[i] = 1/(1+prtp)^(i-year_index)
    end
end

scc = sum(df .* md_interp_ssps)


md_interp_native = MimiIWG._interpolate(marginal_damages_native, model_years, annual_years)

scc_native = sum(df .* md_interp_native)