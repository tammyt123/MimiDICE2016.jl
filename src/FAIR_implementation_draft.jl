### OLD: TESTING WHETHER TEMPERATURE OUTPUT FROM FAIR CAN BE IMPLEMENTED IN DICE -- first pass

## load DICE model
m = MimiDICE2016.get_model()
run(m)

m[:damages, :TATM] # 100 element array: every 5 years from 2015-2510
original_cpc = m[:neteconomy, :CPC] # save for comparison

## FAIR (modified version)
using MimiFAIR

FAIR = MimiFAIR.get_model(usg_scenario = "USG1")
run(FAIR)

FAIR[:temperature, :T] # annual temperature changes 1765-2300
fair_years = collect(1765:1:2300)
dice2016_years = collect(model_years)

temperature = DataFrame(year = fair_years, T = FAIR[:temperature, :T])

input_temp = temperature[[year in dice2016_years for year in fair_years], :T] # 58 element array, needs to be 100. make temperature constant after 2300
append!(input_temp, repeat([input_temp[end]], length(m[:damages, :TATM]) - length(input_temp)))

## set parameter in DICE model
set_param!(m, :TATM, input_temp)

run(m)
m[:damages, :TATM]
m[:climatedynamics, :TATM]
new_cpc = m[:neteconomy, :CPC]

# compare cpc
dice2016_years[58]
original_cpc[58]
new_cpc[58]

