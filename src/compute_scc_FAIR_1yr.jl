# 1. run baseline model (i.e. DICE2016 + FAIR without emissions pulse)
# 2. run marginal model (i.e. DICE2016 + FAIR with emissions pulse) (make sure to scale damages by pulse size)
# 3. calculate marginal damages and take PV to get SCC (note: set damages post 2300 to 0)

####################################################
############# USING MODIFIED FAIR ##################
####################################################

usg_scenario = ["USG1", "USG2", "USG3", "USG4", "USG5"]
pulse_years = [2030, 2040, 2050, 2060]

for usg in usg_scenario

    for pulse_year in pulse_years

        # --------------------------------------------------
        # run baseline model
        # --------------------------------------------------

        ## load DICE model
        m = MimiDICE2016.get_model()
        run(m)
        model_years = 2015:5:2510

        ## FAIR (modified version)
        using MimiFAIR

        # usg = "USG1"

        FAIR = MimiFAIR.get_model(usg_scenario = usg)
        run(FAIR)

        # FAIR[:temperature, :T] # annual temperature changes 1765-2300
        fair_years = collect(1765:1:2300)
        dice2016_years = collect(model_years)

        temperature = DataFrame(year = fair_years, T = FAIR[:temperature, :T])

        input_temp = temperature[[year in dice2016_years for year in fair_years], :T] # 58 element array, needs to be 100. make temperature constant after 2300
        append!(input_temp, repeat([input_temp[end]], length(m[:damages, :TATM]) - length(input_temp)))

        ## set parameter in DICE model
        MimiDICE2016.set_param!(m, :TATM, input_temp)

        run(m)

        # baseline_cpc = m[:neteconomy, :CPC]
        # baseline_c = m[:neteconomy, :C]

        # --------------------------------------------------
        # run marginal model (i.e. add emissions pulse to FAIR)
        # --------------------------------------------------

        ## create DICE marginal model
        # mm = MimiDICE2016.get_model()
        # mm = Mimi.create_marginal_model(m, 5 * 1e9)
        mm = Mimi.create_marginal_model(m, 1e9)
        run(mm)

        ## create FAIR marginal model -- try using create_marginal_model?
        FAIR_mm = MimiFAIR.get_model(usg_scenario = usg)
        run(FAIR_mm)

        ## set pulse year
        # pulse_year = 2030
        pulse_year_index = findall((in)([pulse_year]), collect(1765:2300))

        ## perturb CO2 emissions
        new_emissions = FAIR_mm[:co2_cycle, :E_CO₂]
        new_emissions[pulse_year_index] = new_emissions[pulse_year_index] .+ (1.0 * 12/44) # emissions are in GtC

        MimiFAIR.update_param!(FAIR_mm, :E_CO₂, new_emissions)
        run(FAIR_mm)
        # new_temperature = FAIR_mm[:temperature, :T]

        ## input marginal FAIR temperature into marginal DICE
        new_temperature = DataFrame(year = fair_years, T = FAIR_mm[:temperature, :T])

        new_input_temp = new_temperature[[year in dice2016_years for year in fair_years], :T] # 58 element array, needs to be 100. make temperature constant after 2300
        append!(new_input_temp, repeat([new_input_temp[end]], length(mm[:damages, :TATM]) - length(new_input_temp)))

        ## set parameter in DICE model
        MimiDICE2016.set_param!(mm.modified, :TATM, new_input_temp)

        run(mm.modified)

        # marginalmodel_cpc = mm[:neteconomy, :CPC]
        # marginalmodel_c = mm[:neteconomy, :C]

        # --------------------------------------------------
        # calculate SCC and print result
        # --------------------------------------------------

        scc = MimiDICE2016._compute_scc(mm, year = pulse_year, last_year = 2300, prtp = 0.03, eta = 0.0)
        println(scc)
        
    end
end


# scc_usg1_1yr = MimiDICE2016._compute_scc(mm, year = pulse_year, last_year = 2300, prtp = 0.03, eta = 0.0)



# [scc_usg1,
# scc_usg2, 
# scc_usg3, 
# scc_usg4, 
# scc_usg5]

####################################################
############# USING ORIGINAL FAIR ##################
####################################################

# --------------------------------------------------
# run baseline model
# --------------------------------------------------

## load DICE model
m = MimiDICE2016.get_model()
run(m)
model_years = 2015:5:2510

## FAIR -- make sure to switch branch to master
using MimiFAIR 
rcp = "RCP85"

FAIR = MimiFAIR.get_model(rcp_scenario = rcp, start_year = 1765, end_year = 2300)
run(FAIR)

FAIR[:temperature, :T] # annual temperature changes 1765-2300
fair_years = collect(1765:1:2300)
dice2016_years = collect(model_years)

temperature = DataFrame(year = fair_years, T = FAIR[:temperature, :T])

input_temp = temperature[[year in dice2016_years for year in fair_years], :T] # 58 element array, needs to be 100. make temperature constant after 2300
append!(input_temp, repeat([input_temp[end]], length(m[:damages, :TATM]) - length(input_temp)))

## set parameter in DICE model
MimiDICE2016.set_param!(m, :TATM, input_temp)

run(m)

# baseline_cpc = m[:neteconomy, :CPC]
# baseline_c = m[:neteconomy, :C]

# --------------------------------------------------
# run marginal model (i.e. add emissions pulse to FAIR)
# --------------------------------------------------

## create DICE marginal model
# mm = MimiDICE2016.get_model()
# mm = Mimi.create_marginal_model(m, 5 * 1e9)
mm = Mimi.create_marginal_model(m, 1e9)
run(mm)

## create FAIR marginal model -- try using create_marginal_model?
FAIR_mm = MimiFAIR.get_model(rcp_scenario = rcp, start_year = 1765, end_year = 2300)
run(FAIR_mm)

## set pulse year
pulse_year = 2060
pulse_year_index = findall((in)([pulse_year]), collect(1765:2300))

## perturb CO2 emissions
new_emissions = FAIR_mm[:co2_cycle, :E_CO₂]
new_emissions[pulse_year_index] = new_emissions[pulse_year_index] .+ (1.0 * 12/44) # emissions are in GtC

MimiFAIR.update_param!(FAIR_mm, :E_CO₂, new_emissions)
run(FAIR_mm)
# new_temperature = FAIR_mm[:temperature, :T]

## input marginal FAIR temperature into marginal DICE
new_temperature = DataFrame(year = fair_years, T = FAIR_mm[:temperature, :T])

new_input_temp = new_temperature[[year in dice2016_years for year in fair_years], :T] # 58 element array, needs to be 100. make temperature constant after 2300
append!(new_input_temp, repeat([new_input_temp[end]], length(mm[:damages, :TATM]) - length(new_input_temp)))

## set parameter in DICE model
MimiDICE2016.set_param!(mm.modified, :TATM, new_input_temp)

run(mm.modified)

# marginalmodel_cpc = mm[:neteconomy, :CPC]
# marginalmodel_c = mm[:neteconomy, :C]

# --------------------------------------------------
# calculate SCC
# --------------------------------------------------

MimiDICE2016._compute_scc(mm, year = pulse_year, last_year = 2300, prtp = 0.03, eta = 0.0)

scc_usg1_1yr = MimiDICE2016._compute_scc(mm, year = pulse_year, last_year = 2300, prtp = 0.03, eta = 0.0)



[scc_usg1,
scc_usg2, 
scc_usg3, 
scc_usg4, 
scc_usg5]




# plot emissions

original_FAIR_emissions = FAIR[:co2_cycle, :E_CO₂] # in GtC
original_DICE2016_emissions = m[:emissions, :E] # RCP 85. In GtCO2
DICE2016_emissions_GtC = m[:emissions, :E] .* 12/44

plot(dice2016_years, DICE2016_emissions_GtC)
plot(dice2016_years, original_DICE2016_emissions)
plot(fair_years, original_FAIR_emissions)

DICE = MimiDICE2016.get_model()
run(DICE)
dice_emissions = DICE[:emissions, :E]
plot(model_years, dice_emissions, title = "DICE2016 Temperature Change")
plot(model_years, DICE[:damages, :TATM], title = "DICE2016 Temperature Change")


