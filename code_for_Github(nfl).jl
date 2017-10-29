#=
This code implements the No Stacking, Type 1, Type 2, Type 3, Type 4, and Type 5 formulations
described in the paper Winning Daily Fantasy Hockey Contests Using Integer Programming by
Hunter, Vielma, and Zaman. We have made an attempt to describe the code in great detail, with the
hope that you will use your expertise to build better formulations.
=#

# To install DataFrames, simply run Pkg.add("DataFrames")
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

# path_players is a string that gives the path to the csv file with the skaters information (see example file for suggested format)
path_players = "example_players.csv"

# path_defense is a string that gives the path to the csv file with the goalies information (see example file for suggested format)
path_defense = "example_defense.csv"

# path_to_output is a string that gives the path to the csv file that will give the outputted results
path_to_output= "output.csv"



# This is a function that creates one lineup using the No Stacking formulation from the paper
function one_lineup_no_stacking(players, defenses, lineups, num_overlap, num_players, num_defenses, qb, rb, wr, te, num_teams, players_teams, defense_opponents, team_lines, num_lines, P1_info)
    m = Model(solver=GLPKSolverMIP())

    # Variable for players in lineup.
    @defVar(m, players_lineup[i=1:num_players], Bin)

    # Variable for defense in lineup.
    @defVar(m, defense_lineup[i=1:num_defense], Bin)


    # One defense constraint
    @addConstraint(m, sum{defense_lineup[i], i=1:num_defense} == 1)

    # Eight players constraint
    @addConstraint(m, sum{players_lineup[i], i=1:num_players} == 8)

    # one qb
    @addConstraint(m, sum{qb[i]*players_lineup[i], i=1:num_players} == 1)
	
    # between 2 and 3 rbs
    @addConstraint(m, sum{rbs[i]*players_lineup[i], i=1:num_players} <= 3)
    @addConstraint(m, 2 <= sum{rbs[i]*players_lineup[i], i=1:num_players})

    # between 3 and 4 wrs
    @addConstraint(m, sum{wrs[i]*players_lineup[i], i=1:num_players} <= 4)
    @addConstraint(m, 3<=sum{wrs[i]*players_lineup[i], i=1:num_players})

    # between 2 and 3 tes
    @addConstraint(m, 2 <= sum{tes[i]*players_lineup[i], i=1:num_players})
    @addConstraint(m, sum{tes[i]*players_lineup[i], i=1:num_players} <= 3)

    # Financial Constraint
    @addConstraint(m, sum{players[i,:Salary]*players_lineup[i], i=1:num_players} + sum{defense[i,:Salary]*defense_lineup[i], i=1:num_defense} <= 50000)

    # at least 3 different teams for the 8 skaters constraints
    @defVar(m, used_team[i=1:num_teams], Bin)
    @addConstraint(m, constr[i=1:num_teams], used_team[i] <= sum{players_teams[t, i]*players_lineup[t], t=1:num_players})
    @addConstraint(m, sum{used_team[i], i=1:num_teams} >= 3)

    # Overlap Constraint
    @addConstraint(m, constr[i=1:size(lineups)[2]], sum{lineups[j,i]*players_lineup[j], j=1:num_players} + sum{lineups[num_players+j,i]*defense_lineup[j], j=1:num_defense} <= num_overlap)


    # Objective
    @setObjective(m, Max, sum{players[i,:Projection]*players_lineup[i], i=1:num_players} + sum{defense[i,:Projection]*defense_lineup[i], i=1:num_defense})


    # Solve the integer programming problem
    println("Solving Problem...")
    @printf("\n")
    status = solve(m);


    # Puts the output of one lineup into a format that will be used later
    if status==:Optimal
        players_lineup_copy = Array(Int64, 0)
        for i=1:num_players
            if getValue(players_lineup[i]) >= 0.9 && getValue(players_lineup[i]) <= 1.1
                players_lineup_copy = vcat(players_lineup_copy, fill(1,1))
            else
                players_lineup_copy = vcat(players_lineup_copy, fill(0,1))
            end
        end
        for i=1:num_defense
            if getValue(defense_lineup[i]) >= 0.9 && getValue(defense_lineup[i]) <= 1.1
                players_lineup_copy = vcat(players_lineup_copy, fill(1,1))
            else
                players_lineup_copy = vcat(players_lineup_copy, fill(0,1))
            end
        end
        return(players_lineup_copy)
    end
end





# This is a function that creates one lineup using the Type 1 formulation from the paper
function one_lineup_Type_1(players, defense, lineups, num_overlap, num_players, num_defense, qb, rbs, wrs, tes, num_teams, players_teams, defense_opponents, team_lines, num_lines, P1_info)
    m = Model(solver=GLPKSolverMIP())

    # Variable for players in lineup
    @defVar(m, players_lineup[i=1:num_players], Bin)

    # Variable for defense in lineup
    @defVar(m, defense_lineup[i=1:num_defense], Bin)


    # One defense constraint
    @addConstraint(m, sum{defense_lineup[i], i=1:num_defense} == 1)

    # Eight players constraint
    @addConstraint(m, sum{players_lineup[i], i=1:num_players} == 8)
	
	# one qb
	@addConstraint(m, sum{qb[i]*players_lineup[i], i=1:num_players} == 1)

    # between 2 and 3 rbs
    @addConstraint(m, sum{rbs[i]*players_lineup[i], i=1:num_players} <= 3)
    @addConstraint(m, 2 <= sum{rbs[i]*players_lineup[i], i=1:num_players})

    # between 3 and 4 wrs
    @addConstraint(m, sum{wrs[i]*players_lineup[i], i=1:num_players} <= 4)
    @addConstraint(m, 3<=sum{wrs[i]*players_lineup[i], i=1:num_players})

    # between 2 and 3 tes
    @addConstraint(m, 2 <= sum{tes[i]*players_lineup[i], i=1:num_players})
    @addConstraint(m, sum{tes[i]*players_lineup[i], i=1:num_players} <= 3)


    # Financial Constraint
    @addConstraint(m, sum{players[i,:Salary]*players_lineup[i], i=1:num_players} + sum{defense[i,:Salary]*defense_lineup[i], i=1:num_defense} <= 50000)


    # At least 3 different teams for the 8 players constraint
    @defVar(m, used_team[i=1:num_teams], Bin)
    @addConstraint(m, constr[i=1:num_teams], used_team[i] <= sum{players_teams[t, i]*players_lineup[t], t=1:num_players})
    @addConstraint(m, sum{used_team[i], i=1:num_teams} >= 3)


    # No defense going against players constraint
    @addConstraint(m, constr[i=1:num_defense], 6*defense_lineup[i] + sum{defense_opponents[k, i]*players_lineup[k], k=1:num_players}<=6)


    # Must have at least one complete line in each lineup
    @defVar(m, line_stack[i=1:num_lines], Bin)
    @addConstraint(m, constr[i=1:num_lines], 2*line_stack[i] <= sum{team_lines[k,i]*players_lineup[k], k=1:num_players})
    @addConstraint(m, sum{line_stack[i], i=1:num_lines} >= 1)
	
	 # The rbs must be on Power Play 1
    @addConstraint(m, sum{sum{rbs[i]*P1_info[i,j]*players_lineup[i], i=1:num_players}, j=1:num_teams} ==  sum{rbs[i]*players_lineup[i], i=1:num_players})


    # Overlap Constraint
    @addConstraint(m, constr[i=1:size(lineups)[2]], sum{lineups[j,i]*players_lineup[j], j=1:num_players} + sum{lineups[num_players+j,i]*defense_lineup[j], j=1:num_defense} <= num_overlap)


    # Objective
    @setObjective(m, Max, sum{players[i,:Projection]*players_lineup[i], i=1:num_players} + sum{defense[i,:Projection]*defense_lineup[i], i=1:num_defense} )


    # Solve the integer programming problem
    println("Solving Problem...")
    @printf("\n")
    status = solve(m);

  # Puts the output of one lineup into a format that will be used later
    if status==:Optimal
        players_lineup_copy = Array(Int64, 0)
        for i=1:num_players
            if getValue(players_lineup[i]) >= 0.9 && getValue(players_lineup[i]) <= 1.1
                players_lineup_copy = vcat(players_lineup_copy, fill(1,1))
            else
                players_lineup_copy = vcat(players_lineup_copy, fill(0,1))
            end
        end
        for i=1:num_defense
            if getValue(defense_lineup[i]) >= 0.9 && getValue(defense_lineup[i]) <= 1.1
                players_lineup_copy = vcat(players_lineup_copy, fill(1,1))
            else
                players_lineup_copy = vcat(players_lineup_copy, fill(0,1))
            end
        end
        return(players_lineup_copy)
    end
end



#=
formulation is the type of formulation that you would like to use. Feel free to customize the formulations. In our paper we considered
the Type 4 formulation in great detail, but we have included the code for all of the formulations dicussed in the paper here. For instance,
if you would like to create lineups without stacking, change one_lineup_Type_4 below to one_lineup_no_stacking
=#
formulation = one_lineup_Type_1








function create_lineups(num_lineups, num_overlap, path_players, path_defense, formulation, path_to_output)
    #=
    num_lineups is an integer that is the number of lineups
    num_overlap is an integer that gives the overlap between each lineup
    path_players is a string that gives the path to the players csv file
    path_defense is a string that gives the path to the defense csv file
    formulation is the type of formulation you would like to use (for instance one_lineup_Type_1, one_lineup_Type_2, etc.)
    path_to_output is a string where the final csv file with your lineups will be
    =#


    # Load information for players table
    players = readtable(path_players)

    # Load information for defense table
    defense = readtable(path_defense)

    # Number of players
    num_players = size(players)[1]

    # Number of defense
    num_defense = size(defense)[1]

    # qb stores the information on which players are qbs
    qb = Array(Int64, 0)

    # rbs stores the information on which players are rbs
    rbs = Array(Int64, 0)

    # wrs stores the information on which players are wrs
    wrs = Array(Int64, 0)
	
    # tes stores the information on which players are tes
    tes = Array(Int64, 0)

    #=
    Process the position information in the players file to populate the qbs,
    rbs, wrs, and tes with the corresponding correct information
    =#
    for i =1:num_players
        if players[i,:Position] == "qb" 
            qb=vcat(qb,fill(1,1))
            rbs=vcat(rbs,fill(0,1))
            wrs=vcat(wrs,fill(0,1))
	    tes=vcat(tes,fill(0,1))		
        elseif players[i,:Position] == "rbs"
            qb=vcat(qb,fill(0,1))
            rbs=vcat(rbs,fill(1,1))
            wrs=vcat(wrs,fill(0,1))
	    tes=vcat(tes,fill(0,1))
        elseif players[i,:Position] == "wrs" 
            qb=vcat(qb,fill(0,1))
	    rbs=vcat(rbs,fill(0,1))
            wrs=vcat(wrs,fill(1,1))
            tes=vcat(tes,fill(0,1))
        elseif players[i,:Position] == "tes"
	    qb=vcat(qb,fill(0,1))
	    rbs=vcat(rbs,fill(0,1))
            wrs=vcat(wrs,fill(0,1))
	    tes=vcat(tes,fill(1,1))	
        end
    end
	

    # Create team indicators from the information in the players file
    teams = unique(players[:Team])

    # Total number of teams
    num_teams = size(teams)[1]

    # player_info stores information on which team each player is on
    player_info = zeros(Int, size(teams)[1])

    # Populate player_info with the corresponding information
    for j=1:size(teams)[1]
        if players[1, :Team] == teams[j]
            player_info[j] =1
        end
    end
    players_teams = player_info'


    for i=2:num_players
        player_info = zeros(Int, size(teams)[1])
        for j=1:size(teams)[1]
            if players[i, :Team] == teams[j]
                player_info[j] =1
            end
        end
        players_teams = vcat(players_teams, player_info')
    end



    # Create goalie identifiers so you know who they are playing
    opponents = defense[:Opponent]
    defense_teams = defense[:Team]
    defense_opponents=[]
    for num = 1:size(teams)[1]
        if opponents[1] == teams[num]
            defense_opponents = players_teams[:, num]
        end
    end
    for num = 2:size(opponents)[1]
        for num_2 = 1:size(teams)[1]
            if opponents[num] == teams[num_2]
                defense_opponents = hcat(defense_opponents, players_teams[:,num_2])
            end
        end
    end




    # Create line indicators so you know which players are on which lines
    L1_info = zeros(Int, num_players)
    L2_info = zeros(Int, num_players)
    L3_info = zeros(Int, num_players)
    L4_info = zeros(Int, num_players)
    for num=1:size(players)[1]
        if players[:Team][num] == teams[1]
            if players[:Line][num] == "1"
                L1_info[num] = 1
            elseif players[:Line][num] == "2"
                L2_info[num] = 1
            elseif players[:Line][num] == "3"
                L3_info[num] = 1
            elseif players[:Line][num] == "4"
                L4_info[num] = 1
            end
        end
    end
    team_lines = hcat(L1_info, L2_info, L3_info, L4_info)


    for num2 = 2:size(teams)[1]
        L1_info = zeros(Int, num_players)
        L2_info = zeros(Int, num_players)
        L3_info = zeros(Int, num_players)
        L4_info = zeros(Int, num_players)
        for num=1:size(players)[1]
            if players[:Team][num] == teams[num2]
                if players[:Line][num] == "1"
                    L1_info[num] = 1
                elseif players[:Line][num] == "2"
                    L2_info[num] = 1
                elseif players[:Line][num] == "3"
                    L3_info[num] = 1
                elseif players[:Line][num] == "4"
                    L4_info[num] = 1
                end
            end
        end
        team_lines = hcat(team_lines, L1_info, L2_info, L3_info, L4_info)
    end
    num_lines = size(team_lines)[2]


    # Lineups using formulation as the stacking type
    the_lineup= formulation(players, defense, hcat(zeros(Int, num_players + num_defense), zeros(Int, num_players + num_defense)), num_overlap, num_players, num_defense, qb, rbs, wrs, tes, num_teams, players_teams, defense_opponents, team_lines, num_lines, P1_info)
    the_lineup2 = formulation(players, defense, hcat(the_lineup, zeros(Int, num_players + num_defense)), num_overlap, num_players, num_defense, qb, rbs, wrs, tes, num_teams, players_teams, defense_opponents, team_lines, num_lines, P1_info)
    tracer = hcat(the_lineup, the_lineup2)
    for i=1:(num_lineups-2)
        try
            thelineup=formulation(players, defense, tracer, num_overlap, num_players, num_defense, qb, rbs, wrs, tes, num_teams, players_teams, defense_opponents, team_lines, num_lines, P1_info)
            tracer = hcat(tracer,thelineup)
        catch
            break
        end
    end


    # Create the output csv file
    lineup2 = ""
    for j = 1:size(tracer)[2]
        lineup = ["" "" "" "" "" "" "" "" ""]
        for i =1:num_players
            if tracer[i,j] == 1
                if qb[i]==1
                    if lineup[1]==""
                        lineup[1] = string(players[i,1], " ", players[i,2])
                    elseif lineup[9] ==""
                        lineup[9] = string(skaters[i,1], " ", skaters[i,2])
                    end
                elseif rbs[i] == 1
                    if lineup[2] == ""
                        lineup[2] = string(players[i,1], " ", players[i,2])
                    elseif lineup[3] == ""
                        lineup[3] = string(players[i,1], " ", players[i,2])
                    elseif lineup[9] == ""
                        lineup[9] = string(skaters[i,1], " ", skaters[i,2])
                    end
                elseif wrs[i]==1
                    if lineup[4] == ""
                        lineup[4] = string(players[i,1], " ", players[i,2])
                    elseif lineup[5] ==""
                        lineup[5] = string(players[i,1], " ", players[i,2])
			elseif lineup[6] ==""
                        lineup[6] = string(players[i,1], " ", players[i,2])								
                    elseif lineup[9] == ""
                        lineup[9] = string(players[i,1], " ", players[i,2])
		elseif tes[i]==1
                    if lineup[7] == ""
                        lineup[7] = string(players[i,1], " ", players[i,2])
                    elseif lineup[9] == ""
                        lineup[9] = string(skaters[i,1], " ", skaters[i,2])
                    end
                end
            end
        end
        for i =1:num_defense
            if tracer[num_players+i,j] == 1
                lineup[8] = string(defense[i,1], " ", defense[i,2])
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
create_lineups(num_lineups, num_overlap, path_players, path_defense, formulation, path_to_output)
