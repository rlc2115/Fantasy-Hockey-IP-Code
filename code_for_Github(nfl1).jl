#=
This code implements the No Stacking, Type 1, Type 2, Type 3, Type 4, and Type 5 formulations
described in the paper Winning Daily Fantasy Hockey Contests Using Integer Programming by
Hunter, Vielma, and Zaman. We have made an attempt to describe the code in great detail, with the
hope that you will use your expertise to build better formulations.
=#

# To install DataFrames, simply run Pkg.add("DataFrames")p1
using DataFrames

#=
GLPK is an open-source solver, and additionally Cbc is an open-source solver. This code uses GLPK
because we found that it was slightly faster than Cbc in practice. For those that want to build
very sophisticated models, they can buy Gurobi. To install GLPKMathProgInterface, simply run
Pkg.add("GLPKMathProgInterface")
=#
using GLPKMathProgInterface


# Once again, to install run Pkg.add("JuMP")
using JuMP

#=
Variables for solving the problem (change these)
=#
# num_lineups is the total number of lineups
num_lineups = 100

# num_overlap is the maximum overlap of players between the lineups that you create
num_overlap = 7

# path_oPlayers is a string that gives the path to the csv file with the oPlayers information (see example file for suggested format)
path_oPlayers = "example_oPlayers.csv"

# path_defenses is a string that gives the path to the csv file with the defenses information (see example file for suggested format)
path_defenses = "example_defenses.csv"

# path_to_output is a string that gives the path to the csv file that will give the outputted results
path_to_output= "output.csv"



# This is a function that creates one lineup using the No Stacking formulation from the paper
function one_lineup_no_stacking(oPlayers, defenses, lineups, num_overlap, num_oPlayers, num_defenses, qbs, rbs, wrs, tes, num_teams, oPlayers_teams, defense_opponents, team_lines, num_lines, P1_info)m = Model(solver=GLPKSolverMIP())

    # Variable for oPlayers in lineup.
    @defVar(m, oPlayers_lineup[i=1:num_oPlayers], Bin)

    # Variable for defense in lineup.
    @defVar(m, defenses_lineup[i=1:num_defenses], Bin)


    # One defense constraint
    @addConstraint(m, sum{defenses_lineup[i], i=1:num_defenses} == 1)
	
	# Eight oPlayers constraint
    @addConstraint(m, sum{oPlayers_lineup[i], i=1:num_oPlayers} == 8)

	# One QB constraint
	@addConstraint(m, sum{qbs[i]*oPlayers_lineup[i], i=1:num_oPlayers} = 1)

    # between 2 and 3 rbs
    @addConstraint(m, sum{rbs[i]*oPlayers_lineup[i], i=1:num_oPlayers} <= 3)
    @addConstraint(m, 2 <= sum{rbs[i]*oPlayers_lineup[i], i=1:num_oPlayers})

    # between 3 and 4 wrs
    @addConstraint(m, sum{wrs[i]*oPlayers_lineup[i], i=1:num_oPlayers} <= 4)
    @addConstraint(m, 3<=sum{wrs[i]*oPlayers_lineup[i], i=1:num_oPlayers})

    # between 1 and 2 tes
    @addConstraint(m, 1 <= sum{tes[i]*oPlayers_lineup[i], i=1:num_oPlayers})
    @addConstraint(m, sum{tes[i]*oPlayers_lineup[i], i=1:num_oPlayers} <= 2)

    # Financial Constraint
    @addConstraint(m, sum{oPlayers[i,:Salary]*oPlayers_lineup[i], i=1:num_oPlayers} + sum{defenses[i,:Salary]*defenses_lineup[i], i=1:num_defenses} <= 50000)

    # at least 3 different teams for the 8 oPlayers constraints
    @defVar(m, used_team[i=1:num_teams], Bin)
    @addConstraint(m, constr[i=1:num_teams], used_team[i] <= sum{oPlayers_teams[t, i]*oPlayers_lineup[t], t=1:num_oPlayers})
    @addConstraint(m, sum{used_team[i], i=1:num_teams} >= 3)

    # Overlap Constraint
    @addConstraint(m, constr[i=1:size(lineups)[2]], sum{lineups[j,i]*oPlayers_lineup[j], j=1:num_oPlayers} + sum{lineups[num_oPlayers+j,i]*defenses_lineup[j], j=1:num_defenses} <= num_overlap)


    # Objective
    @setObjective(m, Max, sum{oPlayers[i,:Projection]*oPlayers_lineup[i], i=1:num_oPlayers} + sum{defenses[i,:Projection]*defenses_lineup[i], i=1:num_defenses})


    # Solve the integer programming problem
    println("Solving Problem...")
    @printf("\n")
    status = solve(m);


    # Puts the output of one lineup into a format that will be used later
    if status==:Optimal
        oPlayers_lineup_copy = Array(Int64, 0)
        for i=1:num_oPlayers
            if getValue(oPlayers_lineup[i]) >= 0.9 && getValue(oPlayers_lineup[i]) <= 1.1
                oPlayers_lineup_copy = vcat(oPlayers_lineup_copy, fill(1,1))
            else
                oPlayers_lineup_copy = vcat(oPlayers_lineup_copy, fill(0,1))
            end
        end
        for i=1:num_defenses
            if getValue(defenses_lineup[i]) >= 0.9 && getValue(defenses_lineup[i]) <= 1.1
                oPlayers_lineup_copy = vcat(oPlayers_lineup_copy, fill(1,1))
            else
                oPlayers_lineup_copy = vcat(oPlayers_lineup_copy, fill(0,1))
            end
        end
        return(oPlayers_lineup_copy)
    end
end





# This is a function that creates one lineup using the Type 1 formulation from the paper
function one_lineup_Type_1(	oPlayers, 
							defenses, 
							lineups, 
							num_overlap, 
							num_oPlayers, 
							num_defenses,
							qbs, 
							rbs, 
							wrs, 
							tes, 
							num_teams, 
							oPlayers_teams, 
							defense_opponents, 
							team_lines, 
							num_lines, 
							P1_info)
    m = Model(solver=GLPKSolverMIP())

    # Variable for oPlayers in lineup.
    @defVar(m, oPlayers_lineup[i=1:num_oPlayers], Bin)

    # Variable for defense in lineup.
    @defVar(m, defenses_lineup[i=1:num_defenses], Bin)


    # One defense constraint
    @addConstraint(m, sum{defenses_lineup[i], i=1:num_defenses} == 1)
	
	# Eight oPlayers constraint
    @addConstraint(m, sum{oPlayers_lineup[i], i=1:num_oPlayers} == 8)

	# One QB constraint
	@addConstraint(m, sum{qb[i]*oPlayers_lineup[i], i=1:num_oPlayers} = 1)

    # between 2 and 3 rbs
    @addConstraint(m, sum{rbs[i]*oPlayers_lineup[i], i=1:num_oPlayers} <= 3)
    @addConstraint(m, 2 <= sum{rbs[i]*oPlayers_lineup[i], i=1:num_oPlayers})

    # between 3 and 4 wrs
    @addConstraint(m, sum{wrs[i]*oPlayers_lineup[i], i=1:num_oPlayers} <= 4)
    @addConstraint(m, 3<=sum{wrs[i]*oPlayers_lineup[i], i=1:num_oPlayers})

    # between 1 and 2 tes
    @addConstraint(m, 1 <= sum{tes[i]*oPlayers_lineup[i], i=1:num_oPlayers})
    @addConstraint(m, sum{tes[i]*oPlayers_lineup[i], i=1:num_oPlayers} <= 2)


    # Financial Constraint
    @addConstraint(m, sum{oPlayers[i,:Salary]*oPlayers_lineup[i], i=1:num_oPlayers} + sum{defenses[i,:Salary]*defenses_lineup[i], i=1:num_defenses} <= 50000)


    # At least 3 different teams for the 8 oPlayers constraint
    @defVar(m, used_team[i=1:num_teams], Bin)
    @addConstraint(m, constr[i=1:num_teams], used_team[i] <= sum{oPlayers_teams[t, i]*oPlayers_lineup[t], t=1:num_oPlayers})
    @addConstraint(m, sum{used_team[i], i=1:num_teams} >= 3)


    # No defenses going against oPlayers constraint
    @addConstraint(m, constr[i=1:num_defenses], 6*defenses_lineup[i] + sum{defense_opponents[k, i]*oPlayers_lineup[k], k=1:num_oPlayers}<=6)


    # Must have at least one complete line in each lineup
    @defVar(m, line_stack[i=1:num_lines], Bin)
    @addConstraint(m, constr[i=1:num_lines], 3*line_stack[i] <= sum{team_lines[k,i]*oPlayers_lineup[k], k=1:num_oPlayers})
    @addConstraint(m, sum{line_stack[i], i=1:num_lines} >= 1)


    # Must have at least 2 lines with at least two people
    @defVar(m, line_stack2[i=1:num_lines], Bin)
    @addConstraint(m, constr[i=1:num_lines], 2*line_stack2[i] <= sum{team_lines[k,i]*oPlayers_lineup[k], k=1:num_oPlayers})
    @addConstraint(m, sum{line_stack2[i], i=1:num_lines} >= 2)


    # Overlap Constraint
    @addConstraint(m, constr[i=1:size(lineups)[2]], sum{lineups[j,i]*oPlayers_lineup[j], j=1:num_oPlayers} + sum{lineups[num_oPlayers+j,i]*defenses_lineup[j], j=1:num_defenses} <= num_overlap)


    # Objective
    @setObjective(m, Max, sum{oPlayers[i,:Projection]*oPlayers_lineup[i], i=1:num_oPlayers} + sum{defenses[i,:Projection]*defenses_lineup[i], i=1:num_defenses} )


    # Solve the integer programming problem
    println("Solving Problem...")
    @printf("\n")
    status = solve(m);


    # Puts the output of one lineup into a format that will be used later
    if status==:Optimal
        oPlayers_lineup_copy = Array(Int64, 0)
        for i=1:num_oPlayers
            if getValue(oPlayers_lineup[i]) >= 0.9 && getValue(oPlayers_lineup[i]) <= 1.1
                oPlayers_lineup_copy = vcat(oPlayers_lineup_copy, fill(1,1))
            else
                oPlayers_lineup_copy = vcat(oPlayers_lineup_copy, fill(0,1))
            end
        end
        for i=1:num_defenses
            if getValue(defenses_lineup[i]) >= 0.9 && getValue(defenses_lineup[i]) <= 1.1
                oPlayers_lineup_copy = vcat(oPlayers_lineup_copy, fill(1,1))
            else
                oPlayers_lineup_copy = vcat(oPlayers_lineup_copy, fill(0,1))
            end
        end
        return(oPlayers_lineup_copy)
    end
end





# This is a function that creates one lineup using the Type 2 formulation from the paper
function one_lineup_Type_2(	oPlayers, 
							defenses, 
							lineups, 
							num_overlap, 
							num_oPlayers,
							num_defenses,
							qbs,
							rbs, 
							wrs, 
							tes, 
							num_teams, 
							oPlayers_teams, 
							defense_opponents, 
							team_lines, 
							num_lines, 
							P1_info)
    m = Model(solver=GLPKSolverMIP())

    # Variable for oPlayers in lineup.
    @defVar(m, oPlayers_lineup[i=1:num_oPlayers], Bin)

    # Variable for defense in lineup.
    @defVar(m, defenses_lineup[i=1:num_defenses], Bin)


    # One defense constraint
    @addConstraint(m, sum{defenses_lineup[i], i=1:num_defenses} == 1)
	
	# Eight oPlayers constraint
    @addConstraint(m, sum{oPlayers_lineup[i], i=1:num_oPlayers} == 8)

	# One QB constraint
	@addConstraint(m, sum{qb[i]*oPlayers_lineup[i], i=1:num_oPlayers} = 1)

    # between 2 and 3 rbs
    @addConstraint(m, sum{rbs[i]*oPlayers_lineup[i], i=1:num_oPlayers} <= 3)
    @addConstraint(m, 2 <= sum{rbs[i]*oPlayers_lineup[i], i=1:num_oPlayers})

    # between 3 and 4 wrs
    @addConstraint(m, sum{wrs[i]*oPlayers_lineup[i], i=1:num_oPlayers} <= 4)
    @addConstraint(m, 3<=sum{wrs[i]*oPlayers_lineup[i], i=1:num_oPlayers})

    # exactly 2 tes
    @addConstraint(m, 2 == sum{tes[i]*oPlayers_lineup[i], i=1:num_oPlayers})

    # Financial Constraint
    @addConstraint(m, sum{oPlayers[i,:Salary]*oPlayers_lineup[i], i=1:num_oPlayers} + sum{defenses[i,:Salary]*defenses_lineup[i], i=1:num_defenses} <= 50000)


    # at least 3 different teams for the 8 oPlayers constraint
    @defVar(m, used_team[i=1:num_teams], Bin)
    @addConstraint(m, constr[i=1:num_teams], used_team[i] <= sum{oPlayers_teams[t, i]*oPlayers_lineup[t], t=1:num_oPlayers})
    @addConstraint(m, sum{used_team[i], i=1:num_teams} >= 3)


    # No defenses going against oPlayers constraint
    @addConstraint(m, constr[i=1:num_defenses], 6*defenses_lineup[i] + sum{defense_opponents[k, i]*oPlayers_lineup[k], k=1:num_oPlayers}<=6)


    # Must have at least one complete line in each lineup
    @defVar(m, line_stack[i=1:num_lines], Bin)
    @addConstraint(m, constr[i=1:num_lines], 3*line_stack[i] <= sum{team_lines[k,i]*oPlayers_lineup[k], k=1:num_oPlayers})
    @addConstraint(m, sum{line_stack[i], i=1:num_lines} >= 1)


    # Must have at least 2 lines with at least two people
    @defVar(m, line_stack2[i=1:num_lines], Bin)
    @addConstraint(m, constr[i=1:num_lines], 2*line_stack2[i] <= sum{team_lines[k,i]*oPlayers_lineup[k], k=1:num_oPlayers})
    @addConstraint(m, sum{line_stack2[i], i=1:num_lines} >= 2)


    # Overlap Constraint
    @addConstraint(m, constr[i=1:size(lineups)[2]], sum{lineups[j,i]*oPlayers_lineup[j], j=1:num_oPlayers} + sum{lineups[num_oPlayers+j,i]*defenses_lineup[j], j=1:num_defenses} <= num_overlap)


    # Objective
    @setObjective(m, Max, sum{oPlayers[i,:Projection]*oPlayers_lineup[i], i=1:num_oPlayers} + sum{defenses[i,:Projection]*defenses_lineup[i], i=1:num_defenses} )


    # Solve the integer programming problem
    println("Solving Problem...")
    @printf("\n")
    status = solve(m);


    # Puts the output of one lineup into a format that will be used later
    if status==:Optimal
        oPlayers_lineup_copy = Array(Int64, 0)
        for i=1:num_oPlayers
            if getValue(oPlayers_lineup[i]) >= 0.9 && getValue(oPlayers_lineup[i]) <= 1.1
                oPlayers_lineup_copy = vcat(oPlayers_lineup_copy, fill(1,1))
            else
                oPlayers_lineup_copy = vcat(oPlayers_lineup_copy, fill(0,1))
            end
        end
        for i=1:num_defenses
            if getValue(defenses_lineup[i]) >= 0.9 && getValue(defenses_lineup[i]) <= 1.1
                oPlayers_lineup_copy = vcat(oPlayers_lineup_copy, fill(1,1))
            else
                oPlayers_lineup_copy = vcat(oPlayers_lineup_copy, fill(0,1))
            end
        end
        return(oPlayers_lineup_copy)
    end
end




# This is a function that creates one lineup using the Type 3 formulation from the paper
function one_lineup_Type_3(	oPlayers, 
							defenses, 
							lineups, 
							num_overlap, 
							num_oPlayers, 
							num_defenses,
							qbs, 
							rbs, 
							wrs, 
							tes, 
							num_teams, 
							oPlayers_teams, 
							defense_opponents, 
							team_lines, 
							num_lines, 
							P1_info)
    m = Model(solver=GLPKSolverMIP())


    # Variable for oPlayers in lineup.
    @defVar(m, oPlayers_lineup[i=1:num_oPlayers], Bin)

    # Variable for defense in lineup.
    @defVar(m, defenses_lineup[i=1:num_defenses], Bin)


    # One defense constraint
    @addConstraint(m, sum{defenses_lineup[i], i=1:num_defenses} == 1)
	
	# Eight oPlayers constraint
    @addConstraint(m, sum{oPlayers_lineup[i], i=1:num_oPlayers} == 8)

	# One QB constraint
	@addConstraint(m, sum{qb[i]*oPlayers_lineup[i], i=1:num_oPlayers} = 1)

    # between 2 and 3 rbs
    @addConstraint(m, sum{rbs[i]*oPlayers_lineup[i], i=1:num_oPlayers} <= 3)
    @addConstraint(m, 2 <= sum{rbs[i]*oPlayers_lineup[i], i=1:num_oPlayers})

    # between 3 and 4 wrs
    @addConstraint(m, sum{wrs[i]*oPlayers_lineup[i], i=1:num_oPlayers} <= 4)
    @addConstraint(m, 3<=sum{wrs[i]*oPlayers_lineup[i], i=1:num_oPlayers})

    # between 1 and 2 tes
    @addConstraint(m, 1 <= sum{tes[i]*oPlayers_lineup[i], i=1:num_oPlayers})
    @addConstraint(m, sum{tes[i]*oPlayers_lineup[i], i=1:num_oPlayers} <= 2)


    # Financial Constraint
    @addConstraint(m, sum{oPlayers[i,:Salary]*oPlayers_lineup[i], i=1:num_oPlayers} + sum{defenses[i,:Salary]*defenses_lineup[i], i=1:num_defenses} <= 50000)


    # at least 3 different teams for the 8 oPlayers constraint
    @defVar(m, used_team[i=1:num_teams], Bin)
    @addConstraint(m, constr[i=1:num_teams], used_team[i] <= sum{oPlayers_teams[t, i]*oPlayers_lineup[t], t=1:num_oPlayers})
    @addConstraint(m, sum{used_team[i], i=1:num_teams} >= 3)



    # No defenses going against oPlayers
    @addConstraint(m, constr[i=1:num_defenses], 6*defenses_lineup[i] + sum{defense_opponents[k, i]*oPlayers_lineup[k], k=1:num_oPlayers}<=6)

    # Must have at least one complete line in each lineup
    @defVar(m, line_stack[i=1:num_lines], Bin)
    @addConstraint(m, constr[i=1:num_lines], 3*line_stack[i] <= sum{team_lines[k,i]*oPlayers_lineup[k], k=1:num_oPlayers})
    @addConstraint(m, sum{line_stack[i], i=1:num_lines} >= 1)


    # Must have at least 2 lines with at least two people
    @defVar(m, line_stack2[i=1:num_lines], Bin)
    @addConstraint(m, constr[i=1:num_lines], 2*line_stack2[i] <= sum{team_lines[k,i]*oPlayers_lineup[k], k=1:num_oPlayers})
    @addConstraint(m, sum{line_stack2[i], i=1:num_lines} >= 2)



    # The tes must be on Power Play 1 constraint
    @addConstraint(m, sum{sum{tes[i]*P1_info[i,j]*oPlayers_lineup[i], i=1:num_oPlayers}, j=1:num_teams} ==  sum{tes[i]*oPlayers_lineup[i], i=1:num_oPlayers})


    # Overlap Constraint
    @addConstraint(m, constr[i=1:size(lineups)[2]], sum{lineups[j,i]*oPlayers_lineup[j], j=1:num_oPlayers} + sum{lineups[num_oPlayers+j,i]*defenses_lineup[j], j=1:num_defenses} <= num_overlap)



    # Objective
    @setObjective(m, Max, sum{oPlayers[i,:Projection]*oPlayers_lineup[i], i=1:num_oPlayers} + sum{defenses[i,:Projection]*defenses_lineup[i], i=1:num_defenses} )


    # Solve the integer programming problem
    println("Solving Problem...")
    @printf("\n")
    status = solve(m);


    # Puts the output of one lineup into a format that will be used later
    if status==:Optimal
        oPlayers_lineup_copy = Array(Int64, 0)
        for i=1:num_oPlayers
            if getValue(oPlayers_lineup[i]) >= 0.9 && getValue(oPlayers_lineup[i]) <= 1.1
                oPlayers_lineup_copy = vcat(oPlayers_lineup_copy, fill(1,1))
            else
                oPlayers_lineup_copy = vcat(oPlayers_lineup_copy, fill(0,1))
            end
        end
        for i=1:num_defenses
            if getValue(defenses_lineup[i]) >= 0.9 && getValue(defenses_lineup[i]) <= 1.1
                oPlayers_lineup_copy = vcat(oPlayers_lineup_copy, fill(1,1))
            else
                oPlayers_lineup_copy = vcat(oPlayers_lineup_copy, fill(0,1))
            end
        end
        return(oPlayers_lineup_copy)
    end
end




# This is a function that creates one lineup using the Type 4 formulation from the paper
function one_lineup_Type_4(	oPlayers, 
							defenses, 
							lineups, 
							num_overlap, 
							num_oPlayers, 
							num_defenses,
							qbs, 
							rbs, 
							wrs, 
							tes, 
							num_teams, 
							oPlayers_teams, 
							defense_opponents, 
							team_lines, 
							num_lines, 
							P1_info)
    m = Model(solver=GLPKSolverMIP())


    # Variable for oPlayers in lineup.
    @defVar(m, oPlayers_lineup[i=1:num_oPlayers], Bin)

    # Variable for defense in lineup.
    @defVar(m, defenses_lineup[i=1:num_defenses], Bin)


    # One defense constraint
    @addConstraint(m, sum{defenses_lineup[i], i=1:num_defenses} == 1)
	
	# Eight oPlayers constraint
    @addConstraint(m, sum{oPlayers_lineup[i], i=1:num_oPlayers} == 8)

	# One QB constraint
	@addConstraint(m, sum{qb[i]*oPlayers_lineup[i], i=1:num_oPlayers} = 1)

    # between 2 and 3 rbs
    @addConstraint(m, sum{rbs[i]*oPlayers_lineup[i], i=1:num_oPlayers} <= 3)
    @addConstraint(m, 2 <= sum{rbs[i]*oPlayers_lineup[i], i=1:num_oPlayers})

    # between 3 and 4 wrs
    @addConstraint(m, sum{wrs[i]*oPlayers_lineup[i], i=1:num_oPlayers} <= 4)
    @addConstraint(m, 3<=sum{wrs[i]*oPlayers_lineup[i], i=1:num_oPlayers})

    # between 1 and 2 tes
    @addConstraint(m, 1 <= sum{tes[i]*oPlayers_lineup[i], i=1:num_oPlayers})
    @addConstraint(m, sum{tes[i]*oPlayers_lineup[i], i=1:num_oPlayers} <= 2)

    # Financial Constraint
    @addConstraint(m, sum{oPlayers[i,:Salary]*oPlayers_lineup[i], i=1:num_oPlayers} + sum{defenses[i,:Salary]*defenses_lineup[i], i=1:num_defenses} <= 50000)


    # exactly 3 different teams for the 8 oPlayers constraint
    @defVar(m, used_team[i=1:num_teams], Bin)
    @addConstraint(m, constr[i=1:num_teams], used_team[i] <= sum{oPlayers_teams[t, i]*oPlayers_lineup[t], t=1:num_oPlayers})
    @addConstraint(m, constr[i=1:num_teams], sum{oPlayers_teams[t, i]*oPlayers_lineup[t], t=1:num_oPlayers} <= 6*used_team[i])
    @addConstraint(m, sum{used_team[i], i=1:num_teams} == 3)


    # No defenses going against oPlayers
    @addConstraint(m, constr[i=1:num_defenses], 6*defenses_lineup[i] + sum{defense_opponents[k, i]*oPlayers_lineup[k], k=1:num_oPlayers}<=6)


    # Must have at least one complete line in each lineup
    @defVar(m, line_stack[i=1:num_lines], Bin)
    @addConstraint(m, constr[i=1:num_lines], 3*line_stack[i] <= sum{team_lines[k,i]*oPlayers_lineup[k], k=1:num_oPlayers})
    @addConstraint(m, sum{line_stack[i], i=1:num_lines} >= 1)


    # Must have at least 2 lines with at least two people
    @defVar(m, line_stack2[i=1:num_lines], Bin)
    @addConstraint(m, constr[i=1:num_lines], 2*line_stack2[i] <= sum{team_lines[k,i]*oPlayers_lineup[k], k=1:num_oPlayers})
    @addConstraint(m, sum{line_stack2[i], i=1:num_lines} >= 2)



    # The tes must be on Power Play 1
    @addConstraint(m, sum{sum{tes[i]*P1_info[i,j]*oPlayers_lineup[i], i=1:num_oPlayers}, j=1:num_teams} ==  sum{tes[i]*oPlayers_lineup[i], i=1:num_oPlayers})


    # Overlap Constraint
    @addConstraint(m, constr[i=1:size(lineups)[2]], sum{lineups[j,i]*oPlayers_lineup[j], j=1:num_oPlayers} + sum{lineups[num_oPlayers+j,i]*defenses_lineup[j], j=1:num_defenses} <= num_overlap)



    # Objective
    @setObjective(m, Max, sum{oPlayers[i,:Projection]*oPlayers_lineup[i], i=1:num_oPlayers} + sum{defenses[i,:Projection]*defenses_lineup[i], i=1:num_defenses} )


    # Solve the integer programming problem
    println("Solving Problem...")
    @printf("\n")
    status = solve(m);


    # Puts the output of one lineup into a format that will be used later
    if status==:Optimal
        oPlayers_lineup_copy = Array(Int64, 0)
        for i=1:num_oPlayers
            if getValue(oPlayers_lineup[i]) >= 0.9 && getValue(oPlayers_lineup[i]) <= 1.1
                oPlayers_lineup_copy = vcat(oPlayers_lineup_copy, fill(1,1))
            else
                oPlayers_lineup_copy = vcat(oPlayers_lineup_copy, fill(0,1))
            end
        end
        for i=1:num_defenses
            if getValue(defenses_lineup[i]) >= 0.9 && getValue(defenses_lineup[i]) <= 1.1
                oPlayers_lineup_copy = vcat(oPlayers_lineup_copy, fill(1,1))
            else
                oPlayers_lineup_copy = vcat(oPlayers_lineup_copy, fill(0,1))
            end
        end
        return(oPlayers_lineup_copy)
    end
end


# This is a function that creates one lineup using the Type 5 formulation from the paper
function one_lineup_Type_5(	oPlayers, 
							defenses, 
							lineups, 
							num_overlap, 
							num_oPlayers, 
							num_defenses,
							qbs, 
							rbs, 
							wrs, 
							tes, 
							num_teams, 
							oPlayers_teams, 
							defense_opponents, 
							team_lines, 
							num_lines, 
							P1_info)
    m = Model(solver=GLPKSolverMIP())

    # Variable for oPlayers in lineup.
    @defVar(m, oPlayers_lineup[i=1:num_oPlayers], Bin)

    # Variable for defense in lineup.
    @defVar(m, defenses_lineup[i=1:num_defenses], Bin)


    # One defense constraint
    @addConstraint(m, sum{defenses_lineup[i], i=1:num_defenses} == 1)
	
	# Eight oPlayers constraint
    @addConstraint(m, sum{oPlayers_lineup[i], i=1:num_oPlayers} == 8)

	# One QB constraint
	@addConstraint(m, sum{qb[i]*oPlayers_lineup[i], i=1:num_oPlayers} = 1)

    # between 2 and 3 rbs
    @addConstraint(m, sum{rbs[i]*oPlayers_lineup[i], i=1:num_oPlayers} <= 3)
    @addConstraint(m, 2 <= sum{rbs[i]*oPlayers_lineup[i], i=1:num_oPlayers})

    # between 3 and 4 wrs
    @addConstraint(m, sum{wrs[i]*oPlayers_lineup[i], i=1:num_oPlayers} <= 4)
    @addConstraint(m, 3<=sum{wrs[i]*oPlayers_lineup[i], i=1:num_oPlayers})

    # between 1 and 2 tes
    @addConstraint(m, 1 <= sum{tes[i]*oPlayers_lineup[i], i=1:num_oPlayers})
    @addConstraint(m, sum{tes[i]*oPlayers_lineup[i], i=1:num_oPlayers} <= 2)


    # Financial Constraint
    @addConstraint(m, sum{oPlayers[i,:Salary]*oPlayers_lineup[i], i=1:num_oPlayers} + sum{defenses[i,:Salary]*defenses_lineup[i], i=1:num_defenses} <= 50000)


    # exactly 3 different teams for the 8 oPlayers constraint
    @defVar(m, used_team[i=1:num_teams], Bin)
    @addConstraint(m, constr[i=1:num_teams], used_team[i] <= sum{oPlayers_teams[t, i]*oPlayers_lineup[t], t=1:num_oPlayers})
    @addConstraint(m, constr[i=1:num_teams], sum{oPlayers_teams[t, i]*oPlayers_lineup[t], t=1:num_oPlayers} <= 6*used_team[i])
    @addConstraint(m, sum{used_team[i], i=1:num_teams} == 3)



    # No defenses going against oPlayers
    @addConstraint(m, constr[i=1:num_defenses], 6*defenses_lineup[i] + sum{defense_opponents[k, i]*oPlayers_lineup[k], k=1:num_oPlayers}<=6)



    # Must have at least one complete line in each lineup
    @defVar(m, line_stack[i=1:num_lines], Bin)
    @addConstraint(m, constr[i=1:num_lines], 3*line_stack[i] <= sum{team_lines[k,i]*oPlayers_lineup[k], k=1:num_oPlayers})
    @addConstraint(m, sum{line_stack[i], i=1:num_lines} >= 1)

    # Must have at least 2 lines with at least two people
    @defVar(m, line_stack2[i=1:num_lines], Bin)
    @addConstraint(m, constr[i=1:num_lines], 2*line_stack2[i] <= sum{team_lines[k,i]*oPlayers_lineup[k], k=1:num_oPlayers})
    @addConstraint(m, sum{line_stack2[i], i=1:num_lines} >= 2)


    # Overlap Constraint
    @addConstraint(m, constr[i=1:size(lineups)[2]], sum{lineups[j,i]*oPlayers_lineup[j], j=1:num_oPlayers} + sum{lineups[num_oPlayers+j,i]*defenses_lineup[j], j=1:num_defenses} <= num_overlap)


    # Objective
    @setObjective(m, Max, sum{oPlayers[i,:Projection]*oPlayers_lineup[i], i=1:num_oPlayers} + sum{defenses[i,:Projection]*defenses_lineup[i], i=1:num_defenses} )


    # Solve the integer programming problem
    println("Solving Problem...")
    @printf("\n")
    status = solve(m);


    # Puts the output of one lineup into a format that will be used later
    if status==:Optimal
        oPlayers_lineup_copy = Array(Int64, 0)
        for i=1:num_oPlayers
            if getValue(oPlayers_lineup[i]) >= 0.9 && getValue(oPlayers_lineup[i]) <= 1.1
                oPlayers_lineup_copy = vcat(oPlayers_lineup_copy, fill(1,1))
            else
                oPlayers_lineup_copy = vcat(oPlayers_lineup_copy, fill(0,1))
            end
        end
        for i=1:num_defenses
            if getValue(defenses_lineup[i]) >= 0.9 && getValue(defenses_lineup[i]) <= 1.1
                oPlayers_lineup_copy = vcat(oPlayers_lineup_copy, fill(1,1))
            else
                oPlayers_lineup_copy = vcat(oPlayers_lineup_copy, fill(0,1))
            end
        end
        return(oPlayers_lineup_copy)
    end
end



#=
formulation is the type of formulation that you would like to use. Feel free to customize the formulations. In our paper we considered
the Type 4 formulation in great detail, but we have included the code for all of the formulations dicussed in the paper here. For instance,
if you would like to create lineups without stacking, change one_lineup_Type_4 below to one_lineup_no_stacking
=#
formulation = one_lineup_no_stacking








function create_lineups(num_lineups, num_overlap, path_oPlayers, path_defenses, formulation, path_to_output)
    #=
    num_lineups is an integer that is the number of lineups
    num_overlap is an integer that gives the overlap between each lineup
    path_oPlayers is a string that gives the path to the oPlayers csv file (path_oPlayers)
    path_defenses is a string that gives the path to the defenses csv file
    formulation is the type of formulation you would like to use (for instance one_lineup_Type_1, one_lineup_Type_2, etc.)
    path_to_output is a string where the final csv file with your lineups will be
    =#


    # Load information for oPlayers table
    oPlayers = readtable(path_oPlayers)
	oPlayers = readtable(path_oPlayers)

    # Load information for defenses table
	 defenses = readtable(path_defenses)
	defenses = readtable(path_defenses)

    # Number of oPlayers
    num_oPlayers = size(oPlayers)[1]

    # Number of defenses
    num_defenses = size(defenses)[1]

	# qbs stores the information on which players are qbs
	qbs = Array(int64, 0)
    
	# wrs stores the information on which players are wings
    wrs = Array(Int64, 0)

    # rbs stores the information on which players are rbs
    rbs = Array(Int64, 0)

    # tes stores the information on which players are tes
    tes = Array(Int64, 0)

    #=
    Process the position information in the oPlayers file to populate the wrs,
    rbs, and tes with the corresponding correct information
    =#
    for i =1:num_oPlayers
	if oPlayers[i,:Position] == "QB"
		qbs=vcat(qbs,fill(1,1))
		wrs=vcat(wrs,fill(0,1))
		rbs=vcat(rbs,fill(0,1))
		tes=vcat(tes,fill(0,1))
        elseif oPlayers[i,:Position] == "WR"
		qbs=vcat(qbs,fill(0,1))
		wrs=vcat(wrs,fill(1,1))
		rbs=vcat(rbs,fill(0,1))
		tes=vcat(tes,fill(0,1))
	elseif oPlayers[i,:Position] == "RB"
		qbs=vcat(qbs,fill(0,1))
		wrs=vcat(wrs,fill(0,1))
		rbs=vcat(rbs,fill(1,1))
		tes=vcat(tes,fill(0,1))
        elseif oPlayers[i,:Position] == "TE"
		qbs=vcat(qbs,fill(0,1))
		wrs=vcat(wrs,fill(0,1))
		rbs=vcat(rbs,fill(0,1))
		tes=vcat(tes,fill(1,1))
        else
            	qbs=vcat(qbs,fill(0,1))
		wrs=vcat(wrs,fill(0,1))
		rbs=vcat(rbs,fill(0,1))
		tes=vcat(tes,fill(1,1))
        end
    end




    # Create team indicators from the information in the oPlayers file
    teams = unique(oPlayers[:Team])

    # Total number of teams
    num_teams = size(teams)[1]

    # player_info stores information on which team each player is on
    player_info = zeros(Int, size(teams)[1])

    # Populate player_info with the corresponding information
    for j=1:size(teams)[1]
        if oPlayers[1, :Team] == teams[j]
            player_info[j] =1
        end
    end
    oPlayers_teams = player_info'


    for i=2:num_oPlayers
        player_info = zeros(Int, size(teams)[1])
        for j=1:size(teams)[1]
            if oPlayers[i, :Team] == teams[j]
                player_info[j] =1
            end
        end
        oPlayers_teams = vcat(oPlayers_teams, player_info')
    end



    # Create defense identifiers so you know who they are playing
    opponents = defenses[:Opponent]
    defense_teams = defenses[:Team]
    defense_opponents=[]
    for num = 1:size(teams)[1]
        if opponents[1] == teams[num]
            defense_opponents = oPlayers_teams[:, num]
        end
    end
    for num = 2:size(opponents)[1]
        for num_2 = 1:size(teams)[1]
            if opponents[num] == teams[num_2]
                defense_opponents = hcat(defense_opponents, oPlayers_teams[:,num_2])
            end
        end
    end




    # Create line indicators so you know which players are on which lines
    L1_info = zeros(Int, num_oPlayers)
    L2_info = zeros(Int, num_oPlayers)
    L3_info = zeros(Int, num_oPlayers)
    L4_info = zeros(Int, num_oPlayers)
    for num=1:size(oPlayers)[1]
        if oPlayers[:Team][num] == teams[1]
            if oPlayers[:Line][num] == "1"
                L1_info[num] = 1
            elseif oPlayers[:Line][num] == "2"
                L2_info[num] = 1
            elseif oPlayers[:Line][num] == "3"
                L3_info[num] = 1
            elseif oPlayers[:Line][num] == "4"
                L4_info[num] = 1
            end
        end
    end
    team_lines = hcat(L1_info, L2_info, L3_info, L4_info)


    for num2 = 2:size(teams)[1]
        L1_info = zeros(Int, num_oPlayers)
        L2_info = zeros(Int, num_oPlayers)
        L3_info = zeros(Int, num_oPlayers)
        L4_info = zeros(Int, num_oPlayers)
        for num=1:size(oPlayers)[1]
            if oPlayers[:Team][num] == teams[num2]
                if oPlayers[:Line][num] == "1"
                    L1_info[num] = 1
                elseif oPlayers[:Line][num] == "2"
                    L2_info[num] = 1
                elseif oPlayers[:Line][num] == "3"
                    L3_info[num] = 1
                elseif oPlayers[:Line][num] == "4"
                    L4_info[num] = 1
                end
            end
        end
        team_lines = hcat(team_lines, L1_info, L2_info, L3_info, L4_info)
    end
    num_lines = size(team_lines)[2]




    # Create power play indicators
    PP_info = zeros(Int, num_oPlayers)
    for num=1:size(oPlayers)[1]
        if oPlayers[:Team][num]==teams[1]
            if oPlayers[:Power_Play][num] == "1"
                PP_info[num] = 1
            end
        end
    end

    P1_info = PP_info

    for num2=2:size(teams)[1]
        PP_info = zeros(Int, num_oPlayers)
        for num=1:size(oPlayers)[1]
            if oPlayers[:Team][num] == teams[num2]
                if oPlayers[:Power_Play][num] == "1"
                    PP_info[num]=1
                end
            end
        end
        P1_info = hcat(P1_info, PP_info)
    end


    # Lineups using formulation as the stacking type
    the_lineup= formulation(oPlayers, defenses, hcat(zeros(Int, num_oPlayers + num_defenses), zeros(Int, num_oPlayers + num_defenses)), num_overlap, num_oPlayers, num_defenses, qbs, rbs, wrs, tes, num_teams, oPlayers_teams, defense_opponents, team_lines, num_lines, P1_info)
    the_lineup2 = formulation(oPlayers, defenses, hcat(the_lineup, zeros(Int, num_oPlayers + num_defenses)), num_overlap, num_oPlayers, num_defenses, qbs, rbs, wrs, tes, num_teams, oPlayers_teams, defense_opponents, team_lines, num_lines, P1_info)
    tracer = hcat(the_lineup, the_lineup2)
    for i=1:(num_lineups-2)
        try
            thelineup=formulation(oPlayers, defenses, tracer, num_overlap, num_oPlayers, num_defenses, qbs, rbs, wrs, tes, num_teams, oPlayers_teams, defense_opponents, team_lines, num_lines, P1_info)
            tracer = hcat(tracer,thelineup)
        catch
            break
        end
    end


    # Create the output csv file
    lineup2 = ""
    for j = 1:size(tracer)[2]
        lineup = ["" "" "" "" "" "" "" "" ""]
        for i =1:num_oPlayers
            if tracer[i,j] == 1
                if rbs[i]==1
                    if lineup[1]==""
                        lineup[1] = string(oPlayers[i,1], " ", oPlayers[i,2])
                    elseif lineup[2]==""
                        lineup[2] = string(oPlayers[i,1], " ", oPlayers[i,2])
                    elseif lineup[9] ==""
                        lineup[9] = string(oPlayers[i,1], " ", oPlayers[i,2])
                    end
                elseif wrs[i] == 1
                    if lineup[3] == ""
                        lineup[3] = string(oPlayers[i,1], " ", oPlayers[i,2])
                    elseif lineup[4] == ""
                        lineup[4] = string(oPlayers[i,1], " ", oPlayers[i,2])
                    elseif lineup[5] == ""
                        lineup[5] = string(oPlayers[i,1], " ", oPlayers[i,2])
                    elseif lineup[9] == ""
                        lineup[9] = string(oPlayers[i,1], " ", oPlayers[i,2])
                    end
                elseif tes[i]==1
                    if lineup[6] == ""
                        lineup[6] = string(oPlayers[i,1], " ", oPlayers[i,2])
                    elseif lineup[7] ==""
                        lineup[7] = string(oPlayers[i,1], " ", oPlayers[i,2])
                    elseif lineup[9] == ""
                        lineup[9] = string(oPlayers[i,1], " ", oPlayers[i,2])
                    end
                end
            end
        end
        for i =1:num_defenses
            if tracer[num_oPlayers+i,j] == 1
                lineup[8] = string(defenses[i,1], " ", defenses[i,2])
            end
        end
        for name in lineup
            lineup2 = string(lineup2, name, ",")
        end
        lineup2 = chop(lineup2)
        lineup2 = string(lineup2, """
        """)
    end
    outfile = open(path_to_output, "w")
    write(outfile, lineup2)
    close(outfile)
end




# Running the code
create_lineups(num_lineups, num_overlap, path_oPlayers, path_defenses, formulation, path_to_output)
