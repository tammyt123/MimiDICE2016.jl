# using Pkg
# Pkg.activate("development")
# using Revise, Mimi, MimiDICE2016, XLSX, Plots, DataFrames, MimiIWG

#######################################################################################################################
# LOAD SSP PARAMETERS
########################################################################################################################
# Description: Return DICE model loaded with SSP parameters.
#
# Function Arguments:
#
#       ssp:              SSP scenario for GDP and population. Choose from "SSP1", "SSP2", "SSP3", "SSP4", "SSP5".
#       cmip6_scen:       CMIP6 (RCP/SSP) scenario for emissions. Choose from ssp119, ssp126, ssp245, ssp370, ssp370-lowNTCF-aerchmmip, ssp370-lowNTCF-gidden, ssp434, ssp460, ssp534-over, ssp585.
#
#----------------------------------------------------------------------------------------------------------------------

function get_ssp_dice_model(;ssp::String, cmip6_scen::String)
    
    # load model to be modified with SSP inputs
    m = MimiDICE2016.get_model()
    run(m)

    # set gdp
    ssp_gdp = DataFrame(load(dirname(@__FILE__) * "/../data/ssp_params/" * ssp * "_gdp_dice.csv"))
    # ssp_gdp = DataFrame(load("data/ssp_params/" * ssp * "_gdp_dice.csv"))
    set_param!(m, :YGROSS, ssp_gdp[!,2])

    # set co2 emissions
    ssp_emissions = DataFrame(load(dirname(@__FILE__) * "/../data/ssp_params/" * cmip6_scen * "_co2_emissions_dice.csv"))
    # ssp_emissions = DataFrame(load("data/ssp_params/" * cmip6_scen * "_co2_emissions_dice.csv"))
    emissions_input = ssp_emissions[!,3] ./ 1e3 # convert from MtCO2 to GtCO2
    set_param!(m, :E, emissions_input)

    run(m)
    return(m)

end


#######################################################################################################################
# ADD PULSE OF CO2 EMISSIONS TO GIVEN YEAR
########################################################################################################################
# Description: Add a pulse of CO2 emissions to a given year, to DICE model loaded with SSP params.
#
# Function Arguments:
#
#       pulse_year:       Pulse year for SC-GHG calculation.
#       pulse_size:       Pulse size in GtCO2.
#       ssp:              SSP scenario for GDP and population. Choose from "SSP1", "SSP2", "SSP3", "SSP4", "SSP5".
#       cmip6_scen:       CMIP6 (RCP/SSP) scenario for emissions. Choose from ssp119, ssp126, ssp245, ssp370, ssp370-lowNTCF-aerchmmip, ssp370-lowNTCF-gidden, ssp434, ssp460, ssp534-over, ssp585.
#
#----------------------------------------------------------------------------------------------------------------------

function get_ssp_dice_marginal_model(;pulse_year::Int, pulse_size::Float64=1.0, ssp::String, cmip6_scen::String)
    
    ## load base model with ssp params
    mm = MimiDICE2016.get_ssp_dice_model(ssp = ssp, cmip6_scen = cmip6_scen)
    run(mm)

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
    
    return(mm)

end


#######################################################################################################################
# COMPUTE SCC
########################################################################################################################
# Description: Compute SCC from SSP-modified DICE (constant discounting only, for now).
#
# Function Arguments:
#
#       pulse_year:       Pulse year for SCC calculation.
#       pulse_size:       Pulse size in GtCO2.
#       ssp:              SSP scenario for GDP and population. Choose from "SSP1", "SSP2", "SSP3", "SSP4", "SSP5".
#       cmip6_scen:       CMIP6 (RCP/SSP) scenario for emissions. Choose from ssp119, ssp126, ssp245, ssp370, ssp370-lowNTCF-aerchmmip, ssp370-lowNTCF-gidden, ssp434, ssp460, ssp534-over, ssp585.
#       discount_rate:    Constant discount rate, as a decimal.
#       last_year:        Last year for SC-GHG calculation, marginal damages dropped after this year. Defaults to 2300.
#
#----------------------------------------------------------------------------------------------------------------------

function compute_scc_ssp_dice(;discount_rate::Float64, last_year::Int = 2300, pulse_year::Int, pulse_size::Float64=1.0, ssp::String, cmip6_scen::String)
    
    ## load base and marginal dice with ssp params
    m = MimiDICE2016.get_ssp_dice_model(ssp = ssp, cmip6_scen = cmip6_scen)
    mm = MimiDICE2016.get_ssp_dice_marginal_model(;pulse_year = pulse_year, pulse_size = pulse_size, ssp = ssp, cmip6_scen = cmip6_scen)

    # last year defaults to 2300, but make sure it's not > 2510
    if last_year > 2510
        error("`last_year` cannot be greater than 2510.")
    end

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
    return(scc)

end