extensions [ GIS profiler array]
patches-own [
  land-cover
  village-num
  testing-zone
]
turtles-own [
  head-age              ; The age of the household head
  num-wives             ; The number of wives in the household (0 to 4)
  wives-marriage-age    ; A list containing the ages of all wives in a household when they were first married
  wives-current-age     ; A list containing the current ages of all wives in a household
  num-children          ; The total number of children in the household
  num-boys              ; The total number of boys in the household
  boys-ages             ; A list containing the current ages of all boys in a household
  num-girls             ; The total number of girls in the household
  girls-ages            ; A list containing the current ages of all girls in a household
  widows-ages           ; A list containing the current ages of all widows in a household
  num-widows            ; The total number of widows in the household
  
  fishing-payoff-this-yr
  fishing-payoff-past-5-yrs
  fishing-expected-payoff
  
  num-canals               ; Number of canals owned by the household
  canal-payoff-this-yr
  canal-payoff-past-5-yrs
  canal-expected-payoff

  num-fields               ; Number of rice fields owned by the household  
  field-payoff-this-yr
  field-payoff-past-5-yrs
  field-expected-payoff
  
  
  total-wealth          ; The amount of existing wealth owned by a household. Wealth is accumulated from
                        ;     fishing, canals, and rice farming. It is spent on family members, marriage, and
                        ;     investments.
  expected-income       ; The amount of income that a household head expects for next year based on his current investments
  annual-family-costs   ; The amount of income that a household head expects to spend on his family
  getting-married       ; Household heads cannot get married and make investments in the same year. Additionally, a household will
                        ; not invest if they are eligible to get married in the following year. This variable determines whether
                        ; or not a household will invest in productive assets in a given year
  
  
]
globals [
  ; Related to the environment
  ground-raster                 ; Loads information about floodplain background from ASCII file
  village-raster                ; Loads information about village locations from ASCII file
  testing-zones-raster          ; Loads data that separates the habitable cells into four distinct zones for experimentation
  this-year                     ; An integer listing the current year (starts in 1985)
  
  ; Related to demographics
  wife-max-childbearing-age     ; the oldest age at which a wife might have a child
  wife-annual-childbearing-prob ; the yearly probability that a wife will give birth to a child, given that her age is 
                                ;     below or equal to wife-max-childbearing-age
  emigration-probability        ; The probability that a boy will leave the floodplain upon marriage
  stay-in-village-prob          ; The probability that a boy will stay in his own village upon forming a new household,
                                ;     assuming he does not leave the floodplain


  ; Annual Revenues
  ; NOTE: Each of these follow a log-normal distribution
  nco-fishing-payoff-mean
  nco-fishing-payoff-sd
  
  co-fishing-payoff-mean
  co-fishing-payoff-sd

  canal-payoff-mean
  canal-payoff-sd

  field-payoff-mean
  field-payoff-sd
  field-maintenance-cost
  
  ; Costs for investment and marriage
  ;canal-cost
  field-cost
  ;marriage-cost
  ;first-marriage-extra-cost
  
  ; Thresholds for canal ownership
  max-num-canals
  max-num-fields
  
  ; Annual expenses
  adult-annual-cost
  child-annual-cost
  infant-annual-cost
  elderly-annual-cost
  
  ;income-tax-rate
  annual-fishing-cost
  canal-maintenance-cost-mean
  canal-maintenance-cost-sd
  canal-annual-taxes
  
  ;Effects of Boko Haram
  ;boko-haram-start
  ;boko-haram-durationf
  ;bh-revenue-multiplier
  boko-haram-end
  original-income-tax
  revenue-multiplier
]




; ==============================================================================================================
; =====================          PROGRAM FLOW: INITIALIZATION AND YEARLY ACTIONS           =====================
; ==============================================================================================================


to setup
  ;; (for this model to work with NetLogo's new plotting features,
  ;; __clear-all-and-reset-ticks should be replaced with clear-all at
  ;; the beginning of your setup procedure and reset-ticks at the end
  ;; of the procedure.)
  ca
  initialize-globals
  load-gis
  place-households

  ask turtles [
    initialize-expected-payoffs
    initialize-household-attributes
  ]

  reset-ticks
  set this-year 1975
end


to go
  update-year
  
  if this-year = boko-haram-start and boko-haram-duration > 0 [begin-boko-haram-effects]
  if this-year = boko-haram-end [end-boko-haram-effects]
  
  ask turtles [
    update-ages
    children-born
    children-leave-household true
    wives-die
    widows-die
    children-die
    head-dies

    ; Wealth and expenses
    update-payoffs
    update-expected-payoffs    
    update-wealth
    update-expected-income

    ; Spending wealth
    marriage-decision
    investment-decision
  ]
  
  tick
end




; ==============================================================================================================
; =====================                       SETTING GLOBAL VARIABLES                     =====================
; ==============================================================================================================


; The following function loads global variable for family dynamics
to initialize-globals
  set wife-max-childbearing-age 45
  set wife-annual-childbearing-prob 0.2562
  
  set emigration-probability 0.1
  set stay-in-village-prob 0.5

  ; Annual Revenues
  ; NOTE: Each of these follows a log-normal distribution
  set nco-fishing-payoff-mean 460935
  set nco-fishing-payoff-sd 321409
  
  set co-fishing-payoff-mean 202356
  set co-fishing-payoff-sd 288867

  set canal-payoff-mean 571780
  set canal-payoff-sd 556762

  ; Unlike canals and fishing, field revenues follow a standard normal distribution
  set field-payoff-mean 153516
  set field-payoff-sd 113152
  set field-maintenance-cost 50000
  
  ; Costs for investment and marriage
  ;set canal-cost 509950
  set field-cost 300000
  
  ; Annual expenses
  set adult-annual-cost 140000
  set child-annual-cost 70000
  set infant-annual-cost 35000
  set elderly-annual-cost 70000
  
  ;set income-tax-rate 0.1 ; NOTE: As a percentage of total annual income
  set annual-fishing-cost 70000
  set canal-maintenance-cost-mean 168839
  set canal-maintenance-cost-sd 151567
  set canal-annual-taxes 100000
  
  ; Thresholds for canal and field ownership
  ;set min-children-per-canal 2
  set max-num-fields 3
  set max-num-canals 2
  
  ; The year that the effects of Boko Haram end
  set boko-haram-end boko-haram-start + boko-haram-duration
  set original-income-tax income-tax-rate
  set revenue-multiplier 1
end




; ==============================================================================================================
; =====================                     INITIALIZING THE FLOODPLAIN                    =====================
; ==============================================================================================================


; The following function loads the GIS raster with vegetation data
to load-gis
  set ground-raster gis:load-dataset "land_cover_v3.asc" ; loads raster for background
  set village-raster gis:load-dataset "village_boundaries.asc" ; loads raster for village locations
  ;set testing-zones-raster gis:load-dataset "testing_districts.asc" ; loads raster for testing zones
  ; Sets the geographic extent of the world equal to the background data extent
  gis:set-world-envelope gis:envelope-of ground-raster

  ; This section applies the raster data (global) to variables owned by patches  
  gis:apply-raster ground-raster land-cover
  gis:apply-raster village-raster village-num
  ;gis:apply-raster testing-zones-raster testing-zone
  
  ask patches [ if land-cover = 0 [set pcolor gray] ; Plain pixels (not rivers or depressions) are set to gray
    if land-cover = 1 [set pcolor lime] ; Depression pixels are set to the lime color
    if land-cover = 2 [set pcolor blue] ; River pixels are set to blue
    if land-cover = 3 [set pcolor brown] ; Habitable pixels are set to brown. These pixels will hold all households for the model!
     ]
  
  
  ; Uncomment the following line of code to see the four testing zones
  ; ask patches [if land-cover = 3 [set pcolor scale-color brown testing-zone 0 4]]
  
  ; Uncomment the following line of code to see habitable areas by village
  ask patches [if land-cover = 3 [set pcolor scale-color red village-num 1 33]]
end


; The following function places actors representing households for each of the 36 villages
to place-households
  ; The following two lists contain the estimated number of non-canal-owning and canal-owning household per village, respectively
  let nco-hh [11 11 28 9 9 5 9 5 16 38 127 57 3 3 26 21 45 0 106 33 259 165 28 47 92 141 429 9 24 14 19 143 41]
  let co-hh [6 2 2 1 3 1 3 2 5 8 9 4 1 1 9 6 5 0 34 2 23 12 1 10 7 10 39 1 3 1 3 13 3]
    
  ; This populates the study area with each sub-population by village
  populate-group nco-hh 0 orange
  populate-group co-hh 1 yellow
end


; The following function creates households for a given sub-population in the study area based on a list 
; of the number of households in each village
to populate-group [group-list number-of-canals group-color]
  let num-villages length group-list
  let village-iterator 0
  
  ; First, we will create a loop to iterate through the populations within each village
  ; With our current data, the iterator should run 36 times
  while [ village-iterator < num-villages ] [
    ; Within each village, the variable "num-group-members" will represent
    ; The number of households from a certain demographic who live in the village
    let num-group-members item village-iterator group-list
    
    ; Creates all of the turtles for a given village
    create-turtles num-group-members [
      set size 1.2
      set color group-color
      ; If the household is canal-owning, it will start off with one canal. Otherwise, it will start with 0 canals
      set num-canals number-of-canals
      ; Moves the turtle to one of the tiles assigned to one of their village patches
      move-to one-of patches with [village-num = village-iterator + 1 and land-cover = 3]
      ; Randomly positions the turtle within that patch
      set heading 0
      fd random-float 1 - 0.5
      set heading 90
      fd random-float 1 - 0.5    ]

    ; This sub-population has now been initialized within a particular village
    set village-iterator village-iterator + 1  ; Increments our top iterator by 1
  ]
end


; This turtle function assigns demographic values to each household
; For now, this is kept simple: the model is initialized with one household head,
;     no wives, no children, and no assets
to initialize-household-attributes
  ; *** Initial demographic attributes assigned according to the demographic model ***
  ; Initial household attributes are assigned differently depending on whether or not the household
  ; owns a canal
  ifelse num-canals = 0 [
    ; Household head age mean, std.dev.: 35.01, 14.84
    set head-age round (random-normal 35.01 14.84)
    ; Minimum household head age is 18
    if head-age < 18 [set head-age 18]
    
    ; Derived equation for number of wives within non-canal-owning households:
    ; Num Wives = -0.00275 + 0.0320 * head-age + Normal(0,0.681)
    initialize-wives -0.00275 0.0320 0.681
  ][
    ; Household head age mean, std.dev.: 54.07, 16.73
    set head-age round (random-normal 54.07 16.73)
    ; Minimum household head age is 18
    if head-age < 18 [set head-age 18]

    ; Derived equation for number of wives within canal-owning households:
    ; Num Wives = 0.917 + 0.0146 * head-age + Normal(0,0.992)
    initialize-wives 0.917 0.0146 0.992
  ]
  
  initialize-children
  set num-widows 0
  set widows-ages []

  ; Each household starts out with no existing (liquid) wealth, and one field
  set total-wealth 0
  set num-fields 1
end



; This is a turtle function that sets the "num-wives" attribute based on a linear regression
; and a stochastic component.
; Intercept: X-intercept in a regression between household head age and number of wives
; Age-component: dx in a regression between household head age and number of wives
; Standard-dev: The standard deviation of residuals in the regression between household head age and number of wives
to initialize-wives[intercept age-component standard-dev]
  
  ; The number of wives will be assigned based on this formula:
  ; Num-wives = intercept + age-component * head-age + Normal(0,standard-dev)
  set num-wives round ((intercept + age-component * head-age + random-normal 0 standard-dev) / 2)
  ; The number of wives must be at least 0 and no greater than 4
  if num-wives < 0 [set num-wives 0]
  if num-wives > 4 [set num-wives 4]
  
  ; Uncomment the following line of code to visualize families by the number of wives
  ;set color scale-color green num-wives 0 4

  ; The following section of code creates two lists describing the age of wives in the household
  set wives-marriage-age []    ; This list provides the age of each wife at the time of marriage
  set wives-current-age []     ; This list provides the current age of each wife
  
  ; wives-iterator is used to cycle between the wives in the household
  ; "wives-iterator = 0" corresponds to the first wife, "wives-iterator = 1" to the second wife, and so on
  let wives-iterator 0
  
  ; The age of wives were found to strongly correlate with the husband's age at the time of marriage
  ; The husband's age at the time of marriage is therefore estimated for each wife, based on the marriage
  ; number and the husband's current age.
  ; Afterwards, the wife's age at marriage is estimated using the husband's age at marriage.
  ; This calculation is the same for all four sub-populations
  
  let husband-marriage-intercepts [-9.3085 -6.9946 -2.4459 4.7801]
  let husband-marriage-age-components [0.572 0.3995 0.2307 0.0643]
  let husband-marriage-stochastic [9.187 9.215 7.183 12.119]
  
  ; Iterates over each wife
  while [wives-iterator < num-wives][
    ; first, determine how long ago the nth marriage was
    ; this will be based on the lists created above
    ; These lists are based on statistical analysis for all households in the 2014 dataset
    ; Statistical testing did not find significant differences in the time of marriage between sub-populations
    
    
    let marriage-years-ago round (item wives-iterator husband-marriage-intercepts + head-age * item wives-iterator husband-marriage-age-components + random-normal 0 item wives-iterator husband-marriage-stochastic)
    ; The marriage should be in the past
    if marriage-years-ago < 0 [set marriage-years-ago 0]
    
    ; Next, determine the husband's age at that time
    let husband-marriage-age head-age - marriage-years-ago
    
    ; Get the wife's age at marriage from a function, "get-wife-age-at-marriage"
    let this-wife-marriage-age get-wife-age-at-marriage husband-marriage-age
    
    ; Now, add the wife's marriage age to the wives-marriage-age list
    set wives-marriage-age lput this-wife-marriage-age wives-marriage-age 
    
    let this-wife-current-age this-wife-marriage-age + marriage-years-ago
    
    ; Add the wife's current age to the wives-current-age list
    set wives-current-age lput this-wife-current-age wives-current-age
    
    ; Move on to the next item
    set wives-iterator wives-iterator + 1
  ]
  
  ; The wives are now initialized in the lists wives-marriage age and wives-current-age
  ; The number of wives in the household, num-wives, should always be equal to either list length
  
end



to initialize-children
  ; This is a turtle function that determines the number and ages of boys and girls in the household
  ; based on the ages of the wives and when the wives were married
  ; This function is the same for all four sub-populations
  set num-children 0
  set boys-ages []
  set girls-ages []
  
  ; First, determine the "child-bearing" time period for each wife
  ; This time period is defined as the length of time that each wife is married and is able to have children (ages 15 to 45)

  ; Iterates through the wives
  let wives-birth-iterator 0   ; This iterates through the wives    
  while [ wives-birth-iterator < num-wives ][
    let fertility-start-years-ago 0 
    let fertility-end-years-ago 0
    
    ; If this wife is over age 45:
    ifelse item wives-birth-iterator wives-current-age > 45 
      [ifelse item wives-birth-iterator wives-marriage-age < 45
        [ ; If the wife is over 45 and was married younger than 45
          ; She was able to start bearing children when she was married
          ; She stopped being able to bear children when she turned 45 (in this model)
          set fertility-start-years-ago item wives-birth-iterator wives-current-age - item wives-birth-iterator wives-marriage-age
          set fertility-end-years-ago  item wives-birth-iterator wives-current-age - 45
        ]
        [ ; If the wife was over 45 when married, then she was not able to bear children during the marriage
          set fertility-start-years-ago 0
          set fertility-end-years-ago 0
        ]
      ]
      [ ; Otherwise, the wife is younger than 45 (and can therefore still bear children)
        ; She started being able to bear children when she was married
        set fertility-end-years-ago 0
        set fertility-start-years-ago item wives-birth-iterator wives-current-age - item wives-birth-iterator wives-marriage-age
      ]
    
    ; If there are any fertile years, potentially adds children
    if fertility-end-years-ago < fertility-start-years-ago [
      ; A fairly consistent equation for a wife's number of children can be derived
      ; based on the number of "child-bearing years," or the number of married years
      ; when the wife is between the ages of 15 and 45
      ; The equation is y = 0.256 + 0.9495 * x, where "y" is number of children and "x" is child-bearing years
      ; There is a stochastic component based on the standard deviation of the residuals (1.9625)     

      let child-bearing-years fertility-start-years-ago - fertility-end-years-ago
      let this-wife-children round (0.2562 * child-bearing-years + 0.9435 + random-normal 0 1.9625)
      
      if this-wife-children > 0 [
        ; This initializes children in the household
        
        ; First, creates a list of all possible ages for the children by iterating
        ; through the numbers from fertile-end-years-ago to fertile-start-years-ago
        let children-possible-ages []
        let possible-ages-iterator fertility-end-years-ago
        
        while [possible-ages-iterator <= fertility-start-years-ago][
          set children-possible-ages lput possible-ages-iterator children-possible-ages
          set possible-ages-iterator possible-ages-iterator + 1
        ]
        
        ; Now, iterates through the number of children assigned to that wife
        let children-iterator 0
        
        while [children-iterator < this-wife-children][
          ; Assigns gender with a 50% probability
          ifelse random-float 1 > 0.5 [
            ; In this case, it's a boy 
            ; Take a random age from the table of all possible ages and add it to the list of boys' ages
            set boys-ages lput (one-of children-possible-ages) boys-ages
          ]
          [
            ; In this case, it's a girl
            ; Take a random age from the table of all possible ages and add it to the list of girls' ages
            set girls-ages lput (one-of children-possible-ages) girls-ages
          ]
           
          set children-iterator children-iterator + 1
        ]        
      ]
    ]    
    
    set wives-birth-iterator wives-birth-iterator + 1
  ]
  
  ; The number of children currently is calculated
  set num-boys length boys-ages
  set num-girls length girls-ages
  set num-children length boys-ages + length girls-ages
  
  ; Checks once to see if the "split age" (the age at which a child leaves the household)
  ; is less than the current age for any of the children. If so, they would have already 
  ; left the household when the model started, and they are removed.
  ; However, new househols are NOT spawned during initialization
  ;children-leave-household false
end




; Creates a household with the given ethnicity, household head age, and display color
; If "from-floodplain" is true, then the household may stay in the village of the original household
; The new household may appear in the same village as the old household, or in a random habitable
;  location in the study area, based on the global variable "stay-in-village-prob"
; If "gets-married" is true, then the household head will get married at the same time the household
;  is created


; ==============================================================================================================
; =====================       BASIC HOUSEHOLD FUNCTIONS: Initializing, wives, payoffs      =====================
; ==============================================================================================================

to create-household [ how-many-canals how-many-fields this-head-age this-village from-floodplain gets-married ]
  hatch 1 [
    set size 0.7
    set num-canals how-many-canals
    set num-fields how-many-fields
    set total-wealth 0
    ifelse num-canals > 0 [set color yellow][set color orange]
    set head-age this-head-age
    
    ; Initializes empty lists for family demographics
    set num-wives 0
    set wives-current-age []
    set num-children 0
    set num-boys 0 
    set num-girls 0
    set boys-ages []
    set girls-ages []
    
    ; In most cases, a husband will get married at the same time that he starts a new household
    ; This behavior is determined by the gets-married variable
    if gets-married [
      add-wife
    ]

    
    ; Based on the global variable stay-in-village-prob, the new household will either move
    ; to a patch with the same village value or move to a random habitable tile on the
    ; floodplain
    
    ifelse (from-floodplain = true) and (random-float 1 < stay-in-village-prob) [
      ; Moves the turtle to a patch that is within the current village
      move-to one-of patches with [ village-num = this-village ]
    ][
      ; Moves the turtle to a random habitable location on the floodplain
      ; This location is not necessarily the home village of the original household
      move-to one-of patches with [land-cover = 3]
    ]
        
    ; Randomly positions the turtle within the given patch
    set heading 0
    fd random-float 1 - 0.5
    set heading 90
    fd random-float 1 - 0.5
  ]  
end


to add-wife
  ; Estimate the age of this wife based on a reporter, "get-wife-age-at-marriage"
  let this-wife-marriage-age get-wife-age-at-marriage head-age
  
  ; Update household variables accordingly
  set num-wives num-wives + 1
  set wives-current-age lput this-wife-marriage-age wives-current-age
  set wives-marriage-age lput this-wife-marriage-age wives-marriage-age
end


; This turtle function sets expected payoffs for fishing, canals, and fields
to initialize-expected-payoffs
  set fishing-payoff-past-5-yrs []
  set canal-payoff-past-5-yrs []
  set field-payoff-past-5-yrs []

  let year-iterator 0
  while [year-iterator < 5][
    set fishing-payoff-past-5-yrs lput rand-fishing-payoff num-canals fishing-payoff-past-5-yrs 
    set canal-payoff-past-5-yrs lput rand-canal-payoff canal-payoff-past-5-yrs
    set field-payoff-past-5-yrs lput rand-field-payoff field-payoff-past-5-yrs
    
    set year-iterator year-iterator + 1
  ]
  
  set fishing-expected-payoff mean fishing-payoff-past-5-yrs
  set canal-expected-payoff mean canal-payoff-past-5-yrs
  set field-expected-payoff mean field-payoff-past-5-yrs
  
  update-expected-income 
end





; ==============================================================================================================
; =====================         BASIC PAYOFF FUNCTIONS: FISHING, CANALS, AND FIELDS        =====================
; ==============================================================================================================

; This reporter gives a household's baseline payoff from river fishing for the year
to-report rand-fishing-payoff [number-of-canals]
  ; The fishing payoff is determined by a LOG-NORMAL distribution
  ; The mean of the logged dataset is ln-fishing-payoff-mean and the standard deviation is ln-fishing-payoff-sd
  
  ifelse number-of-canals = 0 [
    let this-fishing-payoff ((log-normal nco-fishing-payoff-mean nco-fishing-payoff-sd) * revenue-multiplier)
    if this-fishing-payoff < 0 [set this-fishing-payoff 0]
    report this-fishing-payoff - annual-fishing-cost
  ][
    ; River fishing payoffs for canal-owning households
    ; Only about 70% of canal-owning households receive income from river fishing
    let my-random-num random-float 1
    ifelse my-random-num < .7 [
      let this-co-fishing-payoff ((log-normal co-fishing-payoff-mean co-fishing-payoff-sd) * revenue-multiplier)
      if this-co-fishing-payoff < 0 [set this-co-fishing-payoff 0]
      report this-co-fishing-payoff - annual-fishing-cost 
    ][report 0]
  ]
  
end


; This reporter gives a household's payoff per canal for the year
to-report rand-canal-payoff
  ; The canal payoff is determined by a LOG-NORMAL distribution
  ; The mean of the dataset is canal-payoff-mean and the standard deviation is canal-payoff-sd
    
  ; The canal is also associated with two costs, which are deducted from the net payoff
  ; Canal maintenance costs are distributed across a log-normal distribution
  ; Canal annual taxes are a fixed fee taken by the local government
  let this-year-canal-payoff ((log-normal canal-payoff-mean canal-payoff-sd) * revenue-multiplier) - (random-normal canal-maintenance-cost-mean canal-maintenance-cost-sd)
  if this-year-canal-payoff < 0 [set this-year-canal-payoff 0]

  report this-year-canal-payoff - canal-annual-taxes
end


; This reporter gives a household's payoff per rice field for the year
to-report rand-field-payoff
  ; The field payoff is determined by a RANDOM NORMAL distribution
  let this-field-payoff ((random-normal field-payoff-mean field-payoff-sd) * revenue-multiplier)
  if this-field-payoff < 0 [set this-field-payoff 0]
  report this-field-payoff - field-maintenance-cost
end

; ==============================================================================================================
; =====================              YEARLY FUNCTIONS: UPDATING DEMOGRAPHICS               =====================
; ==============================================================================================================


; Observer function
; Update the year
to update-year
  set this-year this-year + 1
end


; Turtle function adding 1 to the age of each household member
to update-ages
  ; Add 1 to the household head age
  set head-age head-age + 1
  
  ; Set temporary lists that can be used to store the new values
  let wives-temp-list []
  ; Read each value in the existing list and add those values plus one to the temporary list
  foreach wives-current-age [set wives-temp-list lput (? + 1) wives-temp-list]
  ; Set the temporary list as the new ages list
  set wives-current-age wives-temp-list
  
  ; This process is the same for wives, boys, girls, and widows in the family:
  
  let boys-temp-list []
  foreach boys-ages [set boys-temp-list lput (? + 1) boys-temp-list]
  set boys-ages boys-temp-list
  
  let girls-temp-list []
  foreach girls-ages [set girls-temp-list lput (? + 1) girls-temp-list]
  set girls-ages girls-temp-list
  
  let widows-temp-list []
  foreach widows-ages [set wives-temp-list lput (? + 1) wives-temp-list]
  set widows-ages widows-temp-list
end








to children-born
  ; Children born within each household
  ; Iterates between the number of wives

  if length wives-current-age > 0 [
    let wives-iterator 0
    
    while [wives-iterator < length wives-current-age] [
      ; Original code:
      ; If the wife's age is below 45, there is a chance she will have a child
      ;if item wives-iterator wives-current-age < 45 [
      ; Code with slider:
      if item wives-iterator wives-current-age < wife-max-childbearing-age [
        ; Might have a child based on the regression
        ; num-children = 0.2562 * child-bearing-years + (other factors)
        ; Original code (without slider):
        ;if random-float 1 < 0.2562 [
        ; New code (with slider):
        if random-float 1 < wife-annual-childbearing-prob [
          ; A child is added to the family
          ; 50% chance of male, 50% chance of female
          ifelse random-float 1 < 0.5 [
            ; The child is a boy
            set boys-ages lput 0 boys-ages
          ][
            ; The child is a girl
            set girls-ages lput 0 girls-ages           
          ]
        ]
      ]
      set wives-iterator wives-iterator + 1
    ]
  ]
  
  set num-children length boys-ages + length girls-ages
  set num-boys length boys-ages
  set num-girls length girls-ages
end



to children-leave-household[spawn-new-households]
  ; This function checks to see if children have exceeded the "threshold age"
  ; at which they will leave the house.
  ; Girls will marry into other households; their movement is not explicitly included.
  ; Boys are randomly assigned to either emigrate from the floodplain
  ; or to start a new household within the floodplain, in which case a new household
  ; is created.
  ; If "spawn-new-households" is set to false, then no new households will be created when 
  ; boys leave the house. This setting is used during initialization. Otherwise,
  ; "spawn-new-households" should be set as true.
  
  
  let boys-iterator length boys-ages - 1
  
  ; iterate through all the boys
  ; These lists iterate from maximum to 0, so that when items are removed
  ; from the list, it will not change the results of future iterations
  while [boys-iterator >= 0][
    let this-age item boys-iterator boys-ages
    
    if leaves-household-this-year "male" this-age [
      ; If the child is leaving the household, remove him from the list
      set boys-ages remove-item boys-iterator boys-ages

      if spawn-new-households = true [
        ; Check to see whether the boy emigrates or starts a new household.
        ; The probability of emigration is a global variable that will eventually 
        ; be controlled by the user. For now, it is set under the "setup" command
        ; directly above "initialize-household-attributes"  
        if random-float 1 < (1 - emigration-probability) [
          ; Spawn a new household
          let how-many-canals 0
          let village-here [village-num] of patch-here
          let give-how-many-fields 0
          
          if num-fields > 1 [
            ; The father gives his son a field
            set give-how-many-fields 1
            set num-fields num-fields - 1
          ]
          
          create-household how-many-canals give-how-many-fields this-age village-here true false
        ]
      ]
    ]
    
    set boys-iterator boys-iterator - 1
  ]
  
  let girls-iterator length girls-ages - 1
  
  ; iterate through all the girls
  while [girls-iterator >= 0][
    ; If the child is leaving the household, remove her from the list
    let this-age item girls-iterator girls-ages
    
    if leaves-household-this-year "female" this-age [
      set girls-ages remove-item girls-iterator girls-ages
    ] 
    set girls-iterator girls-iterator - 1
  ]
  
  set num-children length boys-ages + length girls-ages
  set num-boys length boys-ages
  set num-girls length girls-ages    
end



; Children die at a set rate based on the dies-this-year function
to children-die
  ; Iterate BACKWARDS through each of the children
  let boys-iterator length boys-ages - 1
  let girls-iterator length girls-ages - 1
  
  while [boys-iterator >= 0][
    ; Random selection based on chance
    if dies-this-year "male" item boys-iterator boys-ages [
      ; One of the boys in the household dies
      set boys-ages remove-item boys-iterator boys-ages
    ]
    set boys-iterator boys-iterator - 1
  ]
  while [girls-iterator >= 0][
    ; Random selection based on chance
    if dies-this-year "female" item girls-iterator girls-ages [
      ; One of the girls in the household dies
      set girls-ages remove-item girls-iterator girls-ages
    ]
    set girls-iterator girls-iterator - 1
  ]
  
  set num-children length boys-ages + length girls-ages
  set num-boys length boys-ages
  set num-girls length girls-ages 
end


; Wives die if they reach their life expectancy
; If wives die, they are removed from the list
to wives-die
  ; Iterate BACKWARDS through each of the wives
  let wives-iterator length wives-current-age - 1
  
  while [wives-iterator >= 0][
    ; If the wife has reached her life expectancy, then she passes away
    if dies-this-year "female" item wives-iterator wives-current-age [
      ; Remove the wife from the household lists
      set wives-current-age remove-item wives-iterator wives-current-age
      set wives-marriage-age remove-item wives-iterator wives-marriage-age
    ]
    set wives-iterator wives-iterator - 1
  ]
  ; Update the number of wives
  set num-wives length wives-current-age
end

; Widows die if they reach their life expectancy
; If widows die, they are removed from the list
to widows-die
  let widows-iterator length widows-ages - 1
  
  while [widows-iterator >= 0][
    if dies-this-year "female" item widows-iterator widows-ages [
      set widows-ages remove-item widows-iterator widows-ages
    ]
    set widows-iterator widows-iterator - 1
  ]
  
  ; Update the number of widows
  set num-widows length widows-ages
end



; This reporter determines whether or not a person dies in a given year
to-report dies-this-year [gender age]
  let this-year-die-prob 0
  ifelse gender = "male" [
    ; This switching logic applies to all males on the floodplain
    if age < 1 [ set this-year-die-prob 0.066 ]
    if age >= 1 and age < 5 [ set this-year-die-prob 0.0154545895 ]
    if age >= 5 and age < 10 [ set this-year-die-prob 0.0043781693 ]
    if age >= 10 and age < 15 [ set this-year-die-prob 0.00285627 ]
    if age >= 15 and age < 20 [ set this-year-die-prob 0.0041950495 ]
    if age >= 20 and age < 25 [ set this-year-die-prob 0.0066683425 ]
    if age >= 25 and age < 30 [ set this-year-die-prob 0.0110202289 ]
    if age >= 30 and age < 35 [ set this-year-die-prob 0.0149397744 ]
    if age >= 35 and age < 40 [ set this-year-die-prob 0.016516663 ]
    if age >= 40 and age < 45 [ set this-year-die-prob 0.0171588335 ]
    if age >= 45 and age < 50 [ set this-year-die-prob 0.0177597107 ]
    if age >= 50 and age < 55 [ set this-year-die-prob 0.0190954814 ]
    if age >= 55 and age < 60 [ set this-year-die-prob 0.0213526036 ]
    if age >= 60 and age < 65 [ set this-year-die-prob 0.0289931664 ]
    if age >= 65 and age < 70 [ set this-year-die-prob 0.0440064017 ]
    if age >= 70 and age < 75 [ set this-year-die-prob 0.0673121253 ]
    if age >= 75 and age < 80 [ set this-year-die-prob 0.0978732061 ]
    if age >= 80 and age < 85 [ set this-year-die-prob 0.1417353059 ]
    if age >= 85 [ set this-year-die-prob .5 ]
  ][
    ; This switching logic applies to all females on the floodplain
    if age < 1 [ set this-year-die-prob 0.0667 ]
    if age >= 1 and age < 5 [ set this-year-die-prob 0.0145912622 ]
    if age >= 5 and age < 10 [ set this-year-die-prob 0.0040527162 ]
    if age >= 10 and age < 15 [ set this-year-die-prob 0.0026944814 ]
    if age >= 15 and age < 20 [ set this-year-die-prob 0.0043171144 ]
    if age >= 20 and age < 25 [ set this-year-die-prob 0.0081931603 ]
    if age >= 25 and age < 30 [ set this-year-die-prob 0.0131619432 ]
    if age >= 30 and age < 35 [ set this-year-die-prob 0.0154288071 ]
    if age >= 35 and age < 40 [ set this-year-die-prob 0.0140915886 ]
    if age >= 40 and age < 45 [ set this-year-die-prob 0.0132885068 ]
    if age >= 45 and age < 50 [ set this-year-die-prob 0.0118369283 ]
    if age >= 50 and age < 55 [ set this-year-die-prob 0.0123828983 ]
    if age >= 55 and age < 60 [ set this-year-die-prob 0.0152585985 ]
    if age >= 60 and age < 65 [ set this-year-die-prob 0.021374408 ]
    if age >= 65 and age < 70 [ set this-year-die-prob 0.0329168754 ]
    if age >= 70 and age < 75 [ set this-year-die-prob 0.0531841559 ]
    if age >= 75 and age < 80 [ set this-year-die-prob 0.0797995056 ]
    if age >= 80 and age < 85 [ set this-year-die-prob 0.1241857069 ]
    if age >= 85 [ set this-year-die-prob .5 ]  
  ]
  
  ; The person has a chance of dying equal to their assigned probability
  ; "True" means the person has died - "False" means the person does not die this year
  ifelse random-float 1 < this-year-die-prob [report true][report false]
end


; This reporter determines a wife's age at marriage based on her husband's age at marriage
to-report get-wife-age-at-marriage [husband-age-at-marriage]
    ; Determine the wife's approximate age based on a known relationship
    ; between the husband's age at the time of marriage and the husband-wife age difference
    let wife-marriage-age round (-12.316 + husband-age-at-marriage * 0.8906 + random-normal 0 19.21)
    report wife-marriage-age
end


; This reporter determines whether or not a child will leave the household this year
to-report leaves-household-this-year [gender age]
  let this-year-leave-prob 0
  ifelse gender = "male" [
    ; This switching logic applies to all household boys on the floodplain
    if age < 10 [set this-year-leave-prob 0 ]
    if age >= 10 and age < 15 [set this-year-leave-prob 0.0026025076 ]
    if age >= 15 and age < 20 [set this-year-leave-prob 0.0351760662 ]
    if age >= 20 and age < 25 [set this-year-leave-prob 0.0725306346 ]
    if age >= 25 and age < 30 [set this-year-leave-prob 0.1005856027 ]
    if age >= 30 and age < 35 [set this-year-leave-prob 0.0691085223 ]
    if age >= 35 and age < 40 [set this-year-leave-prob 0.0817666286 ]
    if age >= 40 and age < 45 [set this-year-leave-prob 0.0627051909 ]
    if age >= 45 and age < 50 [set this-year-leave-prob 0.0918698897 ]
    if age >= 50 and age < 55 [set this-year-leave-prob 0.0778920885 ]
    if age >= 55 and age < 60 [set this-year-leave-prob 0.0650801239 ]
    if age >= 60 and age < 65 [set this-year-leave-prob 0.0688500849 ]
    if age >= 65 and age < 70 [set this-year-leave-prob 0.0303597339 ]
    if age >= 70 and age < 75 [set this-year-leave-prob 0.1972584382 ]
    if age >= 75 and age < 80 [set this-year-leave-prob 0.1294494367 ]
    if age >= 80 [ set this-year-leave-prob 1 ]
  ][
    ; This switching logic applies to all household girls on the floodplain
    if age < 5 [set this-year-leave-prob 0.0060053797 ]
    if age >= 5  and age < 10 [set this-year-leave-prob 0.0148213717 ]
    if age >= 10 and age < 15 [set this-year-leave-prob 0.0968863666 ]
    if age >= 15 and age < 20 [set this-year-leave-prob 0.2139969144 ]
    if age >= 20 and age < 25 [set this-year-leave-prob 0.1097662007 ]
    if age >= 25 and age < 30 [set this-year-leave-prob 0.0814662578 ]
    if age >= 30 and age < 35 [set this-year-leave-prob 0.0596441767 ]
    if age >= 35 and age < 40 [set this-year-leave-prob 0.1514244089 ]
    if age >= 40 and age < 45 [set this-year-leave-prob 0.1141672897 ]
    if age >= 45 and age < 50 [set this-year-leave-prob 0.1294494367 ]
    if age >= 50 and age < 55 [set this-year-leave-prob 0.1972584382 ]
    if age >= 55 [set this-year-leave-prob 1 ]
  ]
  
  ifelse random-float 1 < this-year-leave-prob [report true][report false]
end



; Household heads die when they reach their life expectancy
;   - If any males in the household are already near adulthood (15), they oldest son become the household head, and the wives turn into widows
;   - If there are no boys nearing adulthood, the wives (as widows) and children are added to another household of the same ethnicity

to head-dies
  if (dies-this-year "male" head-age) [
    ; Set the minimum age at which a boy from the family can become the new household head
    let min-household-head-age 15
    
    let maximum-boy-age 0
    
    if length boys-ages > 0 [
      set maximum-boy-age max boys-ages
    ]
    
    ifelse maximum-boy-age >= min-household-head-age [
      ; In this case, there is a boy in the family who can take over
      set head-age maximum-boy-age
      
      ; Remove that boy from the list of children
      let oldest-boy-index position maximum-boy-age boys-ages
      set boys-ages remove-item oldest-boy-index boys-ages
      set num-boys length boys-ages
      set num-children num-boys + num-girls
      
      ; The wives become widows
      foreach wives-current-age [
        set widows-ages lput ? widows-ages
      ]
      set num-widows length widows-ages
      ; Clear the wives variable
      set wives-marriage-age []
      set wives-current-age []
      set num-wives 0
      

    ][
      ; In this case, there is no male family member who can take over
      ; The family members move to another households
      let our-boys boys-ages
      let our-girls girls-ages
      let our-widows sentence wives-current-age widows-ages
      let our-canals num-canals
      
      ask one-of turtles [
        set boys-ages sentence boys-ages our-boys
        set girls-ages sentence girls-ages our-girls
        set widows-ages sentence widows-ages our-widows
        set num-boys length boys-ages
        set num-girls length girls-ages
        set num-widows length widows-ages
        set num-children length boys-ages + length girls-ages
        ifelse num-canals + our-canals > 2 [set num-canals 2][set num-canals num-canals + our-canals]
      ]
      
      die
      ; The current household is then removed
    ]    
  ]
end





; ==============================================================================================================
; =====================                 YEARLY FUNCTIONS: UPDATING WEALTH                  =====================
; ==============================================================================================================


to update-payoffs
  set fishing-payoff-this-yr rand-fishing-payoff num-canals
  ifelse num-canals > 1 [
    let all-my-canal-payoffs []
    let this-canal-iterator 1
    while[this-canal-iterator < num-canals][
      set all-my-canal-payoffs lput rand-canal-payoff all-my-canal-payoffs
      set this-canal-iterator this-canal-iterator + 1
    ]
    set canal-payoff-this-yr mean all-my-canal-payoffs
  ][
    set canal-payoff-this-yr rand-canal-payoff
  ]
  ifelse num-fields > 1 [
    let all-my-field-payoffs []
    let this-field-iterator 1
    while[this-field-iterator < num-fields][
      set all-my-field-payoffs lput rand-field-payoff all-my-field-payoffs
      set this-field-iterator this-field-iterator + 1
    ]
    set field-payoff-this-yr mean all-my-field-payoffs    
  ][
    set field-payoff-this-yr rand-field-payoff
  ]
  
end


to update-expected-payoffs
  ; Remove the first item (payoff 4 years ago) from each of the 5-year lists
  set fishing-payoff-past-5-yrs but-first fishing-payoff-past-5-yrs
  set canal-payoff-past-5-yrs but-first canal-payoff-past-5-yrs
  set field-payoff-past-5-yrs but-first field-payoff-past-5-yrs
  
  ; Add the terms from this year to the list
  set fishing-payoff-past-5-yrs lput fishing-payoff-this-yr fishing-payoff-past-5-yrs
  set canal-payoff-past-5-yrs lput canal-payoff-this-yr canal-payoff-past-5-yrs
  set field-payoff-past-5-yrs lput field-payoff-this-yr field-payoff-past-5-yrs

  ; Average the new list from the past 5 years to get the expected payoffs
  set fishing-expected-payoff mean fishing-payoff-past-5-yrs
  set canal-expected-payoff mean canal-payoff-past-5-yrs
  set field-expected-payoff mean field-payoff-past-5-yrs
end




; This function updates the household's total wealth based on the canal and field payoff for the year
to update-wealth
  ; Determine initial revenue from canals, fields, and fishing for the year
  let income-this-yr fishing-payoff-this-yr + (num-canals * canal-payoff-this-yr) + (num-fields * field-payoff-this-yr)
  ; If the household has positive wealth, deduct income taxes
  if total-wealth > 0 [set income-this-yr (income-this-yr * (1 - income-tax-rate))]
  
  ; Add remaining income to the family wealth
  set total-wealth total-wealth + income-this-yr
  
  ; Determine the total cost of living for all family members
  let all-family-ages (sentence head-age wives-current-age widows-ages boys-ages girls-ages)
  set annual-family-costs 0
  
  foreach all-family-ages[
    if ? < 3 [set annual-family-costs annual-family-costs + infant-annual-cost]
    if (? >= 3 and ? < 12) [set annual-family-costs annual-family-costs + child-annual-cost]
    if (? >= 12 and ? < 60) [set annual-family-costs annual-family-costs + adult-annual-cost]
    if (? >= 60)[set annual-family-costs annual-family-costs + elderly-annual-cost]
  ]
  
  ; If a family's annual food and clothing costs approach their total wealth, they can reduce costs by only eating half of their meals
  ; This reduces family costs by 50%
  if annual-family-costs > total-wealth [set annual-family-costs .5 * annual-family-costs]
  
  ; Subtract cost-of-living for the household
  set total-wealth total-wealth - annual-family-costs

end


; This function updates the household's expected income for next year based on the household's investments
;   and payoffs (revenue - expenses) on them over the past three years
to update-expected-income
  set expected-income (fishing-expected-payoff + (num-canals * canal-expected-payoff) + (num-fields * field-expected-payoff))*(1 - income-tax-rate)
end





; ==============================================================================================================
; =====================             YEARLY FUNCTIONS: MARRIAGE AND INVESTMENTS             =====================
; ==============================================================================================================


; This function decides whether or not a household owner will get married this year
to marriage-decision
  ; Three conditions must be satisfied for marriage:
  ; 1) The household must have less than 4 wives
  ; 2) The household head must expect to be able to support another wife
  ; 3) The household head must have enough wealth to get married
  
  let extra-expected-income expected-income - annual-family-costs
  
  ifelse num-wives < 4 and extra-expected-income >= adult-annual-cost [
    ; The household satisfies conditions (1) and (2)
    
    ; Check to determine whether the household currently has the wealth to afford another marriage
    let this-marriage-cost first-marriage-cost
    ; If the household head has already been married, set the marriage cost to the (lower) other-marriage-cost
    if num-wives > 1 [set this-marriage-cost other-marriage-cost]

    ifelse total-wealth >= this-marriage-cost [
      ; If all three of these statements are true, then the household head will get married
      ; Subtract the cost of the wedding
      set total-wealth total-wealth - this-marriage-cost
      add-wife
      ; The household added a wife this year and cannot invest in canals or fields
      set getting-married true
    ][
      ; If the household does not yet have enough wealth to afford another wedding, check to see 
      ;   if it is expected to afford the wedding next year
      let expected-wealth-next-year total-wealth + (expected-income - annual-family-costs)
      ifelse expected-wealth-next-year >= this-marriage-cost [
        ; In this case, the household is expected to have enough wealth next year to afford another wedding
        ; The household is saving up for a wedding next year and will not purchase canals or fields
        set getting-married true
      ][
        ; In this case, the household would not have enough wealth to afford a wedding next year
        ; The household is free to invest in canals or fields this year
        set getting-married false
      ]
    ]
  ][
    ; In this case, the household already has 4 wives or does not yet have the capacity to support another wife
    ; The household is not saving up for marriage in the following year
    set getting-married false
  ]
end


; Households have the option to invest in a new resource (canal or field) each year
; This function determines whether a household will buy a resource at the end of the year
; If so, the function determines which resource to buy
to investment-decision
  if getting-married = false [
    ; Only execute this function if the household can purchase at least one canal or rice field
    ; Requirements for owning a canal:
    ;    - Must have enough wealth to purchase the canal
    ;    - Households can own no more than 2 canals
    let can-own-canal ((total-wealth >= canal-cost) and (total-wealth >= canal-ownership-threshold) and (num-canals < max-num-canals))
    
    ; Requirements for owning a field:
    ;    - Must have enough wealth to purchase the field
    ;    - Households can own no more than 4 fields
    let can-own-field ((total-wealth >= field-cost) and (num-fields < max-num-fields))
    
    ifelse (can-own-canal = true and can-own-field = true )[
      ; In this case, the household can choose between building and canal and buying a field
      ; The canal owner wants to maximize their increase in income for the next year
      
      ifelse (canal-expected-payoff >= field-expected-payoff) [
        ; In this case, the household would expect to earn more from investing in canals
        ; Equal profits also break in favor of canals
        buy-canal
      ][
      ; In this case, the household would expect to earn more from investing in fields
      buy-field    
      ]
    ][
      ; In this case, the household does NOT have the option to choose between resources
      ; The household will try to buy any resource that it can
      if can-own-canal = true [buy-canal]    
      if can-own-field = true [buy-field]
      ; If it cannot buy either resource, the household will do nothing
    ]
    
  ]
end


; This function buys a canal for the household
to buy-canal
  set num-canals num-canals + 1
  ; Update household wealth
  set total-wealth total-wealth - canal-cost
  if color = orange [set color yellow]
end

; This function buys a field for the household
to buy-field
  set num-fields num-fields + 1
  ; Update household wealth
  set total-wealth total-wealth - field-cost
end


to-report log-normal [ this-mean this-sd ]
  ; This function returns a log-normal distribution with the given mean and standard dev
  
  let beta ln (1 + ((this-mean ^ 2)/(this-sd ^ 2)))
  let x exp (random-normal (ln (this-mean) - (beta / 2)) sqrt beta)
  
  report x   
end



; ==============================================================================================================
; =====================                      THE EFFECTS OF BOKO HARAM                     =====================
; ==============================================================================================================

to begin-boko-haram-effects
  set revenue-multiplier bh-revenue-multiplier
end

to end-boko-haram-effects
  set revenue-multiplier 1
end
@#$#@#$#@
GRAPHICS-WINDOW
8
10
516
839
41
66
6.0
1
10
1
1
1
0
1
1
1
-41
41
-66
66
1
1
1
ticks
30.0

BUTTON
530
47
629
93
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
530
98
629
144
NIL
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
533
571
833
751
Total Number of Households
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot count turtles"

TEXTBOX
1151
285
1301
304
Household Averages
15
0.0
1

BUTTON
530
148
629
194
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
531
199
629
256
Current Year
this-year
0
1
14

MONITOR
533
522
641
567
Total Households
count turtles
0
1
11

TEXTBOX
656
51
819
78
Investments & Payoffs
15
0.0
1

PLOT
532
327
833
511
Total Number of Canals
NIL
Canals
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot sum [num-canals] of turtles"

PLOT
838
327
1137
512
Total Number of Rice Fields
NIL
Fields
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot sum [num-fields] of turtles"

MONITOR
532
280
613
325
Total Canals
sum [num-canals] of turtles
17
1
11

MONITOR
838
280
913
325
Total Fields
sum [num-fields] of turtles
17
1
11

MONITOR
1152
314
1271
359
Canals / HH
sum [num-canals] of turtles / count turtles
3
1
11

MONITOR
1152
366
1271
411
Rice fields / HH
sum [num-fields] of turtles / count turtles
5
1
11

MONITOR
1152
416
1272
461
Wives / HH
sum [num-wives] of turtles / count turtles
5
1
11

MONITOR
1151
472
1272
517
HH Size
sum [num-wives + num-children + num-widows + 1] of turtles / count turtles
5
1
11

PLOT
840
571
1141
752
Average Wealth Per Household (FCFA)
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Average" 1.0 0 -16777216 true "" "plot median [total-wealth] of turtles"
"Top 25%" 1.0 0 -11085214 true "" "plot item (round count turtles * .75) sort [total-wealth] of turtles"
"Bottom 25%" 1.0 0 -2139308 true "" "plot item (round count turtles * .25) sort [total-wealth] of turtles"

SLIDER
655
222
884
255
canal-ownership-threshold
canal-ownership-threshold
0
3000000
2000000
100000
1
FCFA
HORIZONTAL

SLIDER
656
77
883
110
income-tax-rate
income-tax-rate
0
1
0.1
0.01
1
/1
HORIZONTAL

SLIDER
655
183
883
216
canal-cost
canal-cost
0
1500000
510000
10000
1
FCFA
HORIZONTAL

SLIDER
654
148
884
181
other-marriage-cost
other-marriage-cost
0
1000000
600000
25000
1
FCFA
HORIZONTAL

SLIDER
655
113
884
146
first-marriage-cost
first-marriage-cost
0
1500000
650000
25000
1
FCFA
HORIZONTAL

SLIDER
937
155
1137
188
bh-revenue-multiplier
bh-revenue-multiplier
0
1
0.5
0.01
1
/1
HORIZONTAL

SLIDER
937
79
1137
112
boko-haram-start
boko-haram-start
1978
2020
1999
1
1
(year)
HORIZONTAL

SLIDER
937
117
1138
150
boko-haram-duration
boko-haram-duration
0
10
5
1
1
years
HORIZONTAL

TEXTBOX
940
53
1145
74
Changes Due to Boko Haram
15
0.0
1

MONITOR
937
192
1098
237
Current Revenue Multiplier
revenue-multiplier
3
1
11

@#$#@#$#@
# Simulating the Economic Impact of Boko Haram on a Cameroonian Floodplain

**Author**: Nathaniel Henry
**Date**: October 22, 2016
**NetLogo Version**: 5.1.0


## About the model:

The agent-based model presented here simulates demographic change and economic activity on the Logone floodplain in northern Cameroon at the level of individual households. Under default conditions, the model demonstrates how the changing relationship between household livelihood, family size, and wealth can explain floodplain-wide economic trends since 1980. Critical decisions about household spending are based on a rational-choice model that links income, investment, and the household head’s marriage prospects. Additionally, household members give birth, leave the household, and die in accordance with known demographic and survey data from the floodplain.

The model also simulates the economic impact of the extremist group Boko Haram on the Logone floodplain. Since 2014, Boko Haram has expanded from northeast Nigeria into the Far North region of Cameroon, threatening the security of Cameroonian and provoking a military response. While the direct threat of Boko Haram attacks remains low on the Logone floodplain, residents face new social and economic pressures related to the disruption of the northeast Nigerian economy and increased military activity in the region. This model was used to conduct in-silico experiments about the magnitude of these pressures on floodplain residents; identify which groups are most vulnerable to the current crisis; and determine whether the short-term disruption facilitated by Boko Haram could precipitate long-term changes to social and economic trends on the floodplain.


## Using the model:

### Initialization

To initialize the model, press the purple `setup` button. The floodplain will be generated and populated with households based on census data and canal ownership records from the late 1970s.

Each patch in the model represents an area of approximately 300m by 300m on the floodplain. Patches are one of four colors: blue, which represents the river; brown, which represents the habitable areas close to the river where floodplain residents live; green, which represents depressions that are filled with water following annual floods; and gray, which represents all other areas on the floodplain.

![Land cover types on the floodplain](images/land_types.png)

These patches were assigned according to physical surveys of the floodplain as well as local knowledge about where people lived on the floodplain. Depressions were included as inputs for a later iteration of the model, but their placement does not affect behavior within this version. Note that the river running along the east side of the model area is the Logone, which serves as the border between Cameroon and Chad. Because our research group did not conduct any surveys of floodplain residents living in Chad, the area to the east of the Logone is marked as uninhabited.

The floodplain is also populated with orange and yellow triangles, each one representing an individual household. Each household is an "agent," the fundamental unit of this model. Households each have a set of unique properties, such as family members, investments, and wealth, and the actions of individual households affect how those properties change over time.

![Households on the floodplain](images/households.png)

In the model, households may invest their wealth to build canals, which are a highly productive method for catching fish on the floodplain. Because individual fishing canals play a central role in the changing social-ecological system on the floodplain, the model represents canal-owning and non-canal-owning households differently. Canal-owning households are yellow, while non-canal-owning households are orange.

Households are initially placed within villages based on Cameroonian census data from 1977-78. To see the boundaries between different villages, uncomment the following line of code within the `load-gis` function:

    ; Uncomment the following line of code to see habitable areas by village
    ask patches [if land-cover = 3 [set pcolor scale-color red village-num 1 36]]

![Village boundaries on the floodplain](images/villages.png)


### Yearly behavior

Once the model is initialized, press the purple `go` button to move forward one year. During this time, all household members will age one year. Wives may have a child, children may leave the household, and family members may die. Households will make a certain amount of money from both river fishing and their existing investments in fields and canals. Then, households will lose a certain amount of money to feeding themselves as well as taxation from local leaders and government organizations. If a household has enough money left over after their expenses have been settled, it may spend that extra money: the household head (almost always an adult male) will choose to take a wife, or else the household will invest in a new field or canal.

To the right of the `setup` and `go` buttons, there are two columns of sliders that can be shifted to affect the model's behavior in different ways. Note that 'FCFA' stands for the local currency, Central African CFA Francs. At the time of publication, $1 US = 603 FCFA.

![Options for 'normal' model behavior](images/options_normal.png)

The first column dictates various expenses and taxes for the household. These settings are true for all years, whether or not Boko Haram is present. The `income-tax-rate` setting dictates what percentage of a household's income will be taken by local and government authorities. Previous literature suggests that the traditional taxation rate is typically around 10%. On the floodplain, adult men are typically allowed to marry up to four times. However, a potential husband must pay for the wedding ceremony and deliver goods to the family of the bride. According to sources on the floodplain, a man's marriage to his first wife is typically more expensive than subsequent marriages. These expenses are captured by the variables `first-marriage-cost` and `other-marriage-cost`, respectively. 


Households must satisfy two requirements to build new fishing canals: not only do they have to pay for the canal's construction, they must also have attained a certain level of social status (and material wealth) within their communities. The `canal-cost` variable captures the cost of construction, while `canal-ownership-threshold` sets the amount of wealth that a household must own in order to build. Fields are a less prestigious investment: they cost 300,000 FCFA to build, and have no wealth requirements.

![Options related to Boko Haram](images/options_bh.png)

The second column contains options about the economic shock caused by Boko Haram. The `boko-haram-start` and `boko-haram-duration` variables set the starting time and length of the economic shock. In reality, the economic shock on the floodplain began in 2013-2014 and has continued through 2016. The `bh-revenue-multiplier` is a number between 0 and 1 that captures the combined loss in household income throughout the shock due to reduced prices for floodplain products, higher prices for consumer goods, higher taxes, and rent-seeking behavior by new actors on the floodplain. In my thesis, I investigated three levels of shocks on the floodplain: a mild shock with a revenue multiplier of .9; a moderate shock with a multiplier of .75; and an extreme shock with a revenue multiplier of .5.

![Key model indicators](images/indicators.png)

On the bottom-right side of the model interface, users can view key indicators of size, investments, and wealth for families on the floodplain. Users can also view these key indicators for individual households by right-clicking on the floodplain map and selecting `follow turtle`.


## References and links:

For more information about the model's construction and purpose, including an ODD description of the model, please see my thesis on the subject:

> Henry, Nathaniel. _Predicting Boko Haram’s Impact on the Logone Floodplain in Cameroon: An Agent-Based Simulation Approach_. Undergraduate Thesis. The Ohio State University, 2016. http://bit.ly/29eWj6p

The model is also available on OpenABM, where it can be downloaded and shared according to the Creative Commons [ShareAlike License](https://creativecommons.org/licenses/by-sa/4.0/). This research is part of [Modeling Regime Shifts in the Logone Floodplain](http://mlab.osu.edu/morsl) (MORSL), an interdisciplinary research project that is studying the shifting socio-ecological dynamics on the Logone floodplain.
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270

@#$#@#$#@
NetLogo 5.1.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="experiment" repetitions="10" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>count turtles</metric>
    <enumeratedValueSet variable="wife-annual-childbearing-prob">
      <value value="0.3768"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="edit-marriage-rates">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="second-wife-marriage-prob">
      <value value="0.0251"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="third-wife-marriage-prob">
      <value value="0.014"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="immigration-pct-musgum">
      <value value="0.7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="annual-immigration">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wife-max-childbearing-age">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fourth-wife-marriage-prob">
      <value value="0.0208"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="household-split-on-death">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="stay-in-village-prob">
      <value value="0.97"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="first-wife-marriage-prob">
      <value value="0.09"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="do-families-immigrate">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="emigration-probability">
      <value value="0.43"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment" repetitions="30" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="35"/>
    <metric>count turtles</metric>
    <metric>mean [num-boys] of turtles with [ethnicity = "kotoko"]</metric>
    <enumeratedValueSet variable="emigration-probability">
      <value value="0.15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="edit-marriage-rates">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="stay-in-village-prob">
      <value value="0.4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="do-families-immigrate">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="immigration-pct-musgum">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="first-wife-marriage-prob">
      <value value="0.09"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wife-max-childbearing-age">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="third-wife-marriage-prob">
      <value value="0.014"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="annual-immigration">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="second-wife-marriage-prob">
      <value value="0.0251"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wife-annual-childbearing-prob">
      <value value="0.2562"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="household-split-on-death">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fourth-wife-marriage-prob">
      <value value="0.0208"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="TESTING BH" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="38"/>
    <metric>sum [num-canals] of turtles</metric>
    <metric>sum [num-fields] of turtles</metric>
    <metric>count turtles</metric>
    <metric>count turtles with [num-canals &gt; 0]</metric>
    <metric>count turtles with [num-canals = 0]</metric>
    <metric>mean [num-wives] of turtles</metric>
    <metric>mean [num-wives] of turtles with [num-canals &gt; 0]</metric>
    <metric>mean [num-wives] of turtles with [num-canals = 0]</metric>
    <metric>mean [num-wives + num-children + num-widows + 1] of turtles</metric>
    <metric>mean [num-wives + num-children + num-widows + 1] of turtles with [num-canals &gt; 0]</metric>
    <metric>mean [num-wives + num-children + num-widows + 1] of turtles with [num-canals = 0]</metric>
    <metric>mean [num-fields] of turtles</metric>
    <metric>mean [num-fields] of turtles with [num-canals &gt; 0]</metric>
    <metric>mean [num-fields] of turtles with [num-canals = 0]</metric>
    <metric>mean [expected-income] of turtles</metric>
    <metric>mean [expected-income] of turtles with [num-canals &gt; 0]</metric>
    <metric>mean [expected-income] of turtles with [num-canals = 0]</metric>
    <metric>item (round count turtles * .25) sort [expected-income] of turtles</metric>
    <metric>item (round count turtles with [num-canals &gt; 0] * .25) sort [expected-income] of turtles with [num-canals &gt; 0]</metric>
    <metric>item (round count turtles with [num-canals = 0] * .25) sort [expected-income] of turtles with [num-canals = 0]</metric>
    <metric>median [expected-income] of turtles</metric>
    <metric>median [expected-income] of turtles with [num-canals &gt; 0]</metric>
    <metric>median [expected-income] of turtles with [num-canals = 0]</metric>
    <metric>item (round count turtles * .75) sort [expected-income] of turtles</metric>
    <metric>item (round count turtles with [num-canals &gt; 0] * .75) sort [expected-income] of turtles with [num-canals &gt; 0]</metric>
    <metric>item (round count turtles with [num-canals = 0] * .75) sort [expected-income] of turtles with [num-canals = 0]</metric>
    <metric>mean [total-wealth] of turtles</metric>
    <metric>mean [total-wealth] of turtles with [num-canals &gt; 0]</metric>
    <metric>mean [total-wealth] of turtles with [num-canals = 0]</metric>
    <metric>item (round count turtles * .25) sort [total-wealth] of turtles</metric>
    <metric>item (round count turtles with [num-canals &gt; 0] * .25) sort [total-wealth] of turtles with [num-canals &gt; 0]</metric>
    <metric>item (round count turtles with [num-canals = 0] * .25) sort [total-wealth] of turtles with [num-canals = 0]</metric>
    <metric>median [total-wealth] of turtles</metric>
    <metric>median [total-wealth] of turtles with [num-canals &gt; 0]</metric>
    <metric>median [total-wealth] of turtles with [num-canals = 0]</metric>
    <metric>item (round count turtles * .75) sort [total-wealth] of turtles</metric>
    <metric>item (round count turtles with [num-canals &gt; 0] * .75) sort [total-wealth] of turtles with [num-canals &gt; 0]</metric>
    <metric>item (round count turtles with [num-canals = 0] * .75) sort [total-wealth] of turtles with [num-canals = 0]</metric>
    <enumeratedValueSet variable="boko-haram-start">
      <value value="1999"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="boko-haram-duration">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="bh-revenue-multiplier">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="bh-income-tax-rate">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="income-tax-rate">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="canal-cost">
      <value value="510000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="other-marriage-cost">
      <value value="600000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="first-marriage-cost">
      <value value="650000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="canal-ownership-threshold">
      <value value="2000000"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180

@#$#@#$#@
0
@#$#@#$#@
