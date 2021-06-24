## function to get baseline DICE-FAIR model (i.e. input temperature vector from FAIR-NCEE into baseline DICE 2016)
function get_dicefair(;usg_scenario::String)
    
    ## load baseline DICE model
    m = MimiDICE2016.get_model()
    run(m)

    ## load baseline FAIR-NCEE
    FAIR = MimiFAIR.get_model(usg_scenario = usg_scenario)
    run(FAIR)

    fair_years = collect(1765:1:2300)
    dice2016_years = collect(2015:5:2510) # can sub in model_years

    temperature = DataFrame(year = fair_years, T = FAIR[:temperature, :T])

    input_temp = temperature[[year in dice2016_years for year in fair_years], :T] # 58 element array, needs to be 100. make temperature constant after 2300
    append!(input_temp, repeat([input_temp[end]], length(m[:damages, :TATM]) - length(input_temp)))

    ## set parameter in DICE model
    MimiDICE2016.set_param!(m, :TATM, input_temp)
    run(m)

    return(m)

end

## function to get marginal DICE-FAIR model (i.e. input perturbed FAIR temperature vector into DICE2016)
## note: FAIR-NCEE must be loaded in environment!!
function get_dicefair_marginal_model(;usg_scenario::String, pulse_year::Int, gas::Symbol=:CO2, pulse_size::Float64=1.0)
    
    ## create DICE2016 marginal model
    m = MimiDICE2016.get_dicefair(usg_scenario = usg_scenario)
    mm = Mimi.create_marginal_model(m, (pulse_size * 1e9))
    run(mm)

    ## get perturbed FAIR temperature vector
    fair_years = collect(1765:1:2300)
    dice2016_years = collect(2015:5:2510) # or use model_years
    new_temperature = MimiFAIR.get_perturbed_fair_temperature(usg_scenario = usg_scenario, pulse_year = pulse_year, gas = gas, pulse_size = pulse_size)
    new_temperature_df = DataFrame(year = fair_years, T = new_temperature)

    new_input_temp = new_temperature_df[[year in dice2016_years for year in fair_years], :T] # 58 element array, needs to be 100. make temperature constant after 2300
    append!(new_input_temp, repeat([new_input_temp[end]], length(model_years) - length(new_input_temp)))

    ## set temperature in marginal DICE model to equal perturbed FAIR temperature
    MimiDICE2016.update_param!(mm.modified, :TATM, new_input_temp)
    run(mm)

    return(mm)

end

## compute SCC from DICE-FAIR
function compute_scc_dicefair(;usg_scenario::String, pulse_year::Int, prtp::Float64, eta::Float64, last_year::Int=2300, pulse_size::Float64=1.0, gas::Symbol=:CO2)
    mm = MimiDICE2016.get_dicefair_marginal_model(usg_scenario = usg_scenario, pulse_year = pulse_year, gas = gas, pulse_size = pulse_size)
    scc = MimiDICE2016._compute_scc(mm, year = pulse_year, last_year = last_year, prtp = prtp, eta = eta)
    return(scc)
end