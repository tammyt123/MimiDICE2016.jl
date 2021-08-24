## manual (non-functional) implementation to check

using Pkg
Pkg.activate("development")
using Revise, Mimi, MimiDICE2016, XLSX, Plots, DataFrames, MimiIWG, CSVFiles

# set root dir
directory = "C:/Users/TTAN/Environmental Protection Agency (EPA)/NCEE Social Cost of Carbon - General/models/Notes/Code"

#----------------------------------------------------------------------------------------------------------------------
# load base model
#----------------------------------------------------------------------------------------------------------------------

#       ssp:              SSP scenario for GDP and population. Choose from "SSP1", "SSP2", "SSP3", "SSP4", "SSP5".
#       cmip6_scen:       CMIP6 (RCP/SSP) scenario for emissions. Choose from ssp119, ssp126, ssp245, ssp370, ssp370-lowNTCF-aerchmmip, ssp370-lowNTCF-gidden, ssp434, ssp460, ssp534-over, ssp585.

ssp = "SSP4"
cmip6_scen = "ssp460"

function load_base_model(;ssp::String, cmip6_scen::String)
    # load model to be modified with SSP inputs
    m = MimiDICE2016.get_model()
    run(m)

    # set gdp
    # ssp_gdp = DataFrame(load(dirname(@__FILE__) * "/../data/ssp_params/" * ssp * "_gdp_dice.csv"))
    ssp_gdp = DataFrame(load("data/ssp_params/" * ssp * "_gdp_dice.csv"))
    set_param!(m, :YGROSS, ssp_gdp[2])

    # set co2 emissions
    # ssp_emissions = DataFrame(load(dirname(@__FILE__) * "/../data/ssp_params/" * cmip6_scen * "_co2_emissions_dice.csv"))
    ssp_emissions = DataFrame(load("data/ssp_params/" * cmip6_scen * "_co2_emissions_dice.csv"))
    emissions_input = ssp_emissions[3] ./ 1e3 # convert from MtCO2 to GtCO2
    set_param!(m, :E, emissions_input)

    run(m)
    return(m)
end

m = load_base_model(ssp = ssp, cmip6_scen = cmip6_scen)

#----------------------------------------------------------------------------------------------------------------------
# explore base model
#----------------------------------------------------------------------------------------------------------------------

dice_years = collect(2015:5:2510)

# load default model for comparison
default_DICE = MimiDICE2016.get_model()
run(default_DICE)

## YGROSS
plot(dice_years, m[:neteconomy, :YGROSS], title = "DICE2016 Global Income", ylabel = "YGROSS", xlabel = "Year", label = "DICE2016 x " * ssp, legend = :topleft)
plot!(dice_years, default_DICE[:neteconomy, :YGROSS], label = "Default DICE2016")
savefig((directory * "/output/ssp/plots/" * "dice_global_income_" * ssp))

## co2 emissions
plot(dice_years, m[:co2cycle, :E], title = "DICE2016 CO2 Emissions", ylabel = "Emissions (GtCO2/year)", xlabel = "Year", label = "DICE2016 x " * ssp, legend = :topright)
plot!(dice_years, default_DICE[:co2cycle, :E], label = "Default DICE2016")
savefig((directory * "/output/ssp/plots/" * "dice_co2_emissions_" * ssp))

## temperature
plot(dice_years, m[:climatedynamics, :TATM], title = "DICE2016 Global Average Temperature", ylabel = "Temperature (Degrees)", xlabel = "Year", label = "DICE2016 x " * ssp, legend = :bottomright)
plot!(dice_years, default_DICE[:climatedynamics, :TATM], label = "Default DICE2016")
savefig((directory * "/output/ssp/plots/" * "dice_temperature_" * ssp))


#----------------------------------------------------------------------------------------------------------------------
# load marginal model
#----------------------------------------------------------------------------------------------------------------------

#       pulse_year:       Pulse year for SC-GHG calculation.
#       pulse_size:       Pulse size in GtCO2.

pulse_year = 2030
pulse_size = 1.0

mm = load_base_model(ssp = ssp, cmip6_scen = cmip6_scen)

## perturb emissions of selected gas in marginal model

# get pulse year index
pulse_year_index = findall((in)([pulse_year]), collect(2015:5:2510))
    
# perturb CO2 emissions
new_emissions = copy(mm[:co2cycle, :E])
new_emissions[pulse_year_index] = new_emissions[pulse_year_index] .+ pulse_size

# update emissions parameter
MimiDICE2016.update_param!(mm, :E, new_emissions)
    
## run marginal model
run(mm)
    

#----------------------------------------------------------------------------------------------------------------------
# explore marginal results
#----------------------------------------------------------------------------------------------------------------------

## load marginal default dice for comparison
default_DICE_mm = MimiDICE2016.get_marginal_model(year = pulse_year)
run(default_DICE_mm)

## co2 emissions
plot(dice_years, mm[:co2cycle, :E] .-m[:co2cycle, :E], title = "DICE2016 CO2 Emissions Pulse", ylabel = "Emissions (GtCO2/year)", xlabel = "Year", label = "DICE2016 x " * ssp, legend = :topright)
plot!(dice_years, default_DICE_mm[:co2cycle, :E] .* 5e9, label = "Default DICE2016")
# savefig((directory * "/output/ssp/plots/" * "dice_co2_emissions_" * ssp))

## temperature
plot(dice_years, mm[:climatedynamics, :TATM] .- m[:climatedynamics, :TATM], title = "DICE2016 Temperature Delta", ylabel = "Temperature (Degrees)", xlabel = "Year", label = "DICE2016 x " * ssp, legend = :bottomright)
plot!(dice_years, default_DICE_mm[:climatedynamics, :TATM] .* 5e9, label = "Default DICE2016")
savefig((directory * "/output/ssp/plots/" * "dice_temperature_delta_" * ssp))




#----------------------------------------------------------------------------------------------------------------------
# calculate scc
#----------------------------------------------------------------------------------------------------------------------

#       discount_rate:    Constant discount rate, as a decimal.
#       last_year:        Last year for SC-GHG calculation, marginal damages dropped after this year. Defaults to 2300.

discount_rate = 0.03
last_year = 2300

## calculate damages
dice_years = collect(2015:5:last_year)
last_year_index = findfirst(isequal(last_year), dice_years)
marginal_damages = (m[:neteconomy, :C] .- mm[:neteconomy, :C])[1:last_year_index] * 1e3 # drop MD after last_year

# interpolate to get annual damages
annual_years = collect(2015:1:last_year)
md_interp = MimiIWG._interpolate(marginal_damages./5, dice_years, annual_years) # md has to be divided by 5 before interpolating because it's originally calculated as 5-year md
    
## calculate discount factors
prtp = discount_rate # constant discounting for now
pulse_year_index = findfirst(isequal(pulse_year), annual_years)
df = zeros(length(annual_years))
for i in 1:length(annual_years)
    if i >= pulse_year_index
        df[i] = 1/(1+prtp)^(i-pulse_year_index)
    end
end

## calculate scc
scc = sum(df .* md_interp) 
scc
