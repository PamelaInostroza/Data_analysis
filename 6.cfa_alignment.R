library(lavaan)
library(lavaan.survey)
library(semPlot)
library(sjlabelled)
memory.limit(15000)
options(survey.lonely.psu="adjust")


# 1. *EqOppoWom* : Equal opportunities and rights for woman  
# 2. *PolParWom* : Equal participation in jobs and politics for woman  
# 3. *Lifestyle* : Immigrant should maintain lifestyle and language  
# 4. *PolParImm* : Equal participation in politics for immigrants  
# 5. *EqOppImMi* : Equal opportunities for education, jobs and rights for immigrants and minorities  

#Newscales <- c("EqOppoWom", "PolParWom", "Lifestyle", "PolParImm", "EqOppImMi", "EqOppEthn")


InverseCod <- c("BS4G6","BS4G9","BS4G13","IS2P24C","IS2P24D","IS2P24F","IS3G24C","IS3G24D","IS3G24F")
#Cycles 2-3 vars reverse whole scale
C1vars <- VarsToUse %>%  filter(Domain == "Scales" & Dataset %in% c("ISG","ISE")) %>% select(VariableC1) %>% na.omit() %>% pull()
C1vars <- C1vars[grepl(paste0(InverseCod, collapse = "|"), C1vars)]
C2vars <- VarsToUse %>%  filter(Domain == "Scales" & Dataset %in% c("ISG","ISE")) %>% select(VariableC2) %>% na.omit() %>% pull()
C2vars <- C2vars[!grepl(paste0(InverseCod, collapse = "|"), C2vars)]
C3vars <- VarsToUse %>%  filter(Domain == "Scales" & Dataset %in% c("ISG","ISE")) %>% select(VariableC3) %>% na.omit() %>% pull()
C3vars <- C3vars[!grepl(paste0(InverseCod, collapse = "|"), C3vars)]

torecod <- c(C1vars, C2vars, C3vars)
if(!any(colnames(ISC_cfa) %in% paste0(c(C1vars, C2vars, C3vars),"."))){
  dat <- data.frame(psych::reverse.code(keys = rep(-1,length(torecod)), 
                                        items = ISC_cfa[torecod], 
                                        mini = rep(1,length(torecod)), 
                                        maxi = rep(4,length(torecod))))
  colnames(dat) <- colnames(ISC_cfa[, torecod])
}

#Copy labels of old variables
label <- NULL
for (i in 1:length(torecod)) {
  label[i] <- eval(parse(text=paste0("get_label(ISC_cfa$",torecod[i],")")))
}

#Add (r) to label for inverse coded variables
labelr <- NULL
for (j in 1:length(InverseCod)) {
  labelr[j] <- paste0(eval(parse(text=paste0("get_label(ISC_cfa$",InverseCod[j],")"))),"(r)")
}

ISC_cfa <- cbind(ISC_cfa[,!colnames(ISC_cfa) %in% torecod], dat)

ISC_cfa[torecod] <- set_label(ISC_cfa[torecod], label)
ISC_cfa[InverseCod] <- set_label(ISC_cfa[InverseCod], labelr)
ISC_cfa[Scales] <-  set_labels(ISC_cfa[Scales], labels = c("strongly disagree" = 1, "disagree" = 2, "agree" = 3, "strongly agree" = 4))


if (any(grepl("99", years$year))){
  if(length(Newscales) == 3){
    model99<-'
    Gend_Equal =~ BS4G1 + BS4G4 + BS4G6 + BS4G9 + BS4G11 + BS4G13
    Immi_Equal =~ BS4H1 + BS4H2 + BS4H3 + BS4H4 + BS4H5
    Ethn_Equal =~ BS4G2 + BS4G5 + BS4G8 + BS4G12
    BS4H1 ~~  BS4H4
    BS4G9 ~~ BS4G13
    '    
  } else if(length(Newscales) == 6){
    
    model99 <-'
      EqOppoWom =~ BS4G1 + BS4G4+ BS4G11 
      PolParWom =~ BS4G6 + BS4G9 + BS4G13
      Lifestyle =~ BS4H1 + BS4H4 
      PolParImm =~ BS4H3 + BS4G12 
      EqOppImMi =~ BS4G2 + BS4G5 + BS4G8 + BS4H2 + BS4H5
      BS4G2 ~~ BS4G5 
      '
  }
  # EqOppoWom : Equal opportunities and rightf for woman
  # PolParWom : Equal participation in jobs and politics for woman
  # Lifestyle : Immigrant should maintain lifestyle and language
  # PolParImm : Equal participation in politics for immigrants
  # EqOppImMi : Equal opportunities for education, jobs and rights for immigrants and minorities

  cat('## CIVED 1999  \n')
  #############1999#########
  index99 <- Itemdesc %>% filter(item != "index") %>% dplyr::select(CIVED_1999) %>% na.omit() %>% pull()

  ds991 <- ISC_cfa %>% filter(!is.na(TOTWGT_Gc1)) %>% 
    dplyr::select(all_of(index99), all_of(Id), IDJK, IDCL, SENWGT_Gc1, GENDER) %>% 
    mutate(GENDER = as.character(GENDER)) 
  ds99 <- ds991 %>% mutate_at(.funs = as.numeric, .vars = index99)
  survey.design99 <- svydesign(ids= ~ IDCL, weights = ~ SENWGT_Gc1, strata = ~ IDJK, nest = TRUE, data=ds99)
  
  cfa99 <- cfa(model99, data = ds99, cluster = c("COUNTRY", "IDSCHOOL"), missing = "fiml")
  survey.fit99 <- lavaan.survey(lavaan.fit = cfa99, survey.design = survey.design99, estimator= "MLMVS")
  
  #summary(cfa99, fit.measures=TRUE)
  #print(modindices(cfa99,sort=T)[1:10,])
  p99 <- cbind(ds99, predict(cfa99)) #Prediction of factor scores should be based on survey design but not possible to obtain in R
  p99 <- p99 %>% mutate(cycle = "C1") %>% 
    dplyr::select(all_of(Id), all_of(Newscales))
  rm(cfa99) #Remove fit to save space in disk
  
  cnt99 <- unique(ds99$COUNTRY)
  meast99 <- NULL
  stdl99 <- NULL
  for (c99 in cnt99) {
     CNTcfa <- cfa(model99, cluster = c("IDSCHOOL"), data = ds99[ds99$COUNTRY == c99,])
    
    survey.cnt99 <- svydesign(ids = ~ IDCL, weights = ~ SENWGT_Gc1, strata = ~ IDJK, nest = TRUE, 
                              data=ds99[ds99$COUNTRY == c99,])
    survey.CNTfit <- lavaan.survey(lavaan.fit = CNTcfa, survey.design = survey.cnt99, estimator= "MLMVS")
    
    meas <- fitMeasures(survey.CNTfit, c("chisq","df", "cfi", "tli","rmsea", "srmr"), output = "matrix")
    meas <- rbind(n = nobs(survey.CNTfit), meas)
    meast99 <- cbind(meast99, meas)
    stdl <- standardizedSolution(survey.CNTfit) %>% 
      filter(op == "=~") %>% 
      mutate(cntry = c99)
    stdl99 <- rbind(stdl99, stdl)
  }
  meast99 <- as.data.frame(t(meast99))
  rownames(meast99) <- cnt99
  rm(CNTcfa)
  
  cat('### CFA - ICCS 1999, all countries')
  cat('  \n')
  cat('  \n')
  meas99 <- fitMeasures(survey.fit99, c("chisq","df","cfi", "tli","rmsea", "srmr"), 
                        output = "matrix")
  knitr::kable(cbind(n = nobs(survey.fit99), round(as.data.frame(t(meas99)), 3))) %>% print() 
  
  cat('  \n')
  cat('### CFA - ICCS 1999, by countries')
  cat('  \n')
  knitr::kable(meast99,digits = 3) %>% print() 
  cat('  \n')
  cat('  \n')
  invisible(semPaths(survey.fit99,"model", "std", "lisrel", edge.label.cex = 0.6, intercepts = FALSE, groups = "latent", 
                     pastel = TRUE, title = FALSE, nCharNodes = 10, nDigits = 1))
  title("CFA measurement model", line = 2)
  cat('  \n')
  cat('  \n')
  
  labels <- data.frame(label = tolower(sjlabelled::get_label(ds991))) 
  labels <- labels %>% filter(!str_detect(rownames(labels), c("IDSTUD|IDSCHOOL|COUNTRY|TOTWGT|GENDER"))) %>% 
    mutate(variable = rownames(.))
  stdl99 <- stdl99 %>% mutate(rhs = factor(rhs, levels = labels$variable, labels = labels$label))
  l1 <- stdl99 %>% data.frame() %>% 
    ggplot(aes(x = est.std, y = rhs, color = reorder(cntry, desc(cntry)))) +
    geom_linerange(aes(xmin = ci.lower, xmax = ci.upper), position = position_dodge(0.4)) +
    geom_jitter(position = position_dodge(0.4)) +
    facet_wrap(. ~ lhs, scales = "free", ncol = 1)+
    geom_text(aes(label=cntry),hjust=0, vjust=1, position = position_dodge(0.4), size = 2) +
    theme(legend.position = "none") +
    ggtitle("Loading distribution of scales - ICCS 1999") +
    ylab("") +
    xlab("Loadings with Confidence Interval") +
    scale_y_discrete(labels = function(x) str_wrap(x, 25) )
  print(l1)

  cat('  \n')
  cat('  \n')
  cat('### Invariance between COUNTRY')
  cat('  \n')
  cat('  \n')
  inv.conf99 <- cfa(model99, data = ds99, cluster = "IDSCHOOL", group = "COUNTRY")
  inv.conf99 <- lavaan.survey(lavaan.fit = inv.conf99, survey.design = survey.design99, estimator= "MLMVS")
  inv.metr99 <- cfa(model99, data = ds99, cluster = "IDSCHOOL", group = "COUNTRY", group.equal = c("loadings"))
  inv.metr99 <- lavaan.survey(lavaan.fit = inv.metr99, survey.design = survey.design99, estimator= "MLMVS")
  inv.scal99 <- cfa(model99, data = ds99, cluster = "IDSCHOOL", group = "COUNTRY", group.equal = c("loadings","intercepts"))
  inv.scal99 <- lavaan.survey(lavaan.fit = inv.scal99, survey.design = survey.design99, estimator= "MLMVS")
  inv.stri99 <- cfa(model99, data = ds99, cluster = "IDSCHOOL", group = "COUNTRY", group.equal = c("loadings","intercepts","lv.variances"))
  inv.stri99 <- lavaan.survey(lavaan.fit = inv.stri99, survey.design = survey.design99, estimator= "MLMVS")

  invarCNT <- data.frame(round(rbind(Configural = fitMeasures(inv.conf99, c("npar", "logl","chisq", "df", "tli", "cfi", "rmsea")),
                                     Metric = fitMeasures(inv.metr99, c("npar", "logl","chisq", "df", "tli", "cfi", "rmsea")),
                                     Scalar = fitMeasures(inv.scal99, c("npar", "logl","chisq", "df", "tli", "cfi", "rmsea")),
                                     Strict = fitMeasures(inv.stri99, c("npar", "logl","chisq", "df", "tli", "cfi", "rmsea"))),3))
  invarCNT <- invarCNT %>% mutate(Invariance = rownames(invarCNT)) %>% relocate(Invariance, .before = npar) %>%
    mutate(D_tli = tli-lag(tli),
           D_cfi = cfi-lag(cfi),
           D_rmsea = rmsea-lag(rmsea)) %>%
    knitr::kable() %>% print()
  cat('  \n')
  cat('  \n')
  rm(inv.conf99, inv.metr99, inv.scal99, inv.stri99) #Remove to save space in disk

  cat('### Invariance between GENDER')
  cat('  \n')
  cat('  \n')
  inv.conf99 <- cfa(model99, data = ds99, cluster = "IDSCHOOL", group = "GENDER")
  inv.conf99 <- lavaan.survey(lavaan.fit = inv.conf99, survey.design = survey.design99, estimator= "MLMVS")
  inv.metr99 <- cfa(model99, data = ds99, cluster = "IDSCHOOL", group = "GENDER", group.equal = c("loadings"))
  inv.metr99 <- lavaan.survey(lavaan.fit = inv.metr99, survey.design = survey.design99, estimator= "MLMVS")
  inv.scal99 <- cfa(model99, data = ds99, cluster = "IDSCHOOL", group = "GENDER", group.equal = c("loadings","intercepts"))
  inv.scal99 <- lavaan.survey(lavaan.fit = inv.scal99, survey.design = survey.design99, estimator= "MLMVS")
  inv.stri99 <- cfa(model99, data = ds99, cluster = "IDSCHOOL", group = "GENDER", group.equal = c("loadings","intercepts","lv.variances"))
  inv.stri99 <- lavaan.survey(lavaan.fit = inv.stri99, survey.design = survey.design99, estimator= "MLMVS")

  invarGNDR <- data.frame(round(rbind(Configural = fitMeasures(inv.conf99, c("npar", "logl","chisq", "df", "tli", "cfi", "rmsea")),
                                      Metric = fitMeasures(inv.metr99, c("npar", "logl","chisq", "df", "tli", "cfi", "rmsea")),
                                      Scalar = fitMeasures(inv.scal99, c("npar", "logl","chisq", "df", "tli", "cfi", "rmsea")),
                                      Strict = fitMeasures(inv.stri99, c("npar", "logl","chisq", "df", "tli", "cfi", "rmsea"))),3))
  invarGNDR <- invarGNDR %>% mutate(Invariance = rownames(invarGNDR)) %>% relocate(Invariance, .before = npar) %>%
    mutate(D_tli = tli-lag(tli),
           D_cfi = cfi-lag(cfi),
           D_rmsea = rmsea-lag(rmsea)) %>%
    knitr::kable() %>% print()
  cat('  \n')
  cat('  \n')
  rm(inv.conf99, inv.metr99, inv.scal99, inv.stri99) #Remove to save space in disk
}
if (any(grepl("09", years$year))){
  if(length(Newscales) == 3){
    # model09<-'
    #   Gend_Equal =~ IS2P24A + IS2P24B + IS2P24C + IS2P24D + IS2P24E + IS2P24F
    #   Immi_Equal =~ IS2P26A + IS2P26B + IS2P26C + IS2P26D + IS2P26E
    #   Ethn_Equal =~ IS2P25A + IS2P25B + IS2P25C + IS2P25D + IS2P25E
    #   IS2P24A ~~ IS2P24B
    #   IS2P25A ~~ IS2P25B
    #   IS2P26A ~~ IS2P26D
    # '
    model09<-'
      Gend_Equal =~ IS2P24A + IS2P24B + IS2P24E
      Immi_Equal =~ IS2P26A + IS2P26C + IS2P26D + IS2P26E
      Ethn_Equal =~ IS2P25A + IS2P25B + IS2P25C  + IS2P25E
    '
  } else if(length(Newscales) == 6){
    model09 <-'
      EqOppoWom =~ IS2P24A + IS2P24B + IS2P24E
      PolParWom =~ IS2P24C + IS2P24D + IS2P24F
      Lifestyle =~ IS2P26A + IS2P26D 
      PolParImm =~ IS2P26C + IS2P25D 
      EqOppImMi =~ IS2P25A + IS2P25B + IS2P25C + IS2P26B + IS2P25E
      IS2P24A ~~ IS2P24B
      IS2P25A ~~ IS2P25B
      '
  }
  # EqOppoWom : Equal opportunities and rightf for woman
  # PolParWom : Equal participation in jobs and politics for woman
  # Lifestyle : Immigrant should maintain lifestyle and language
  # PolParImm : Equal participation in politics for immigrants
  # EqOppImMi : Equal opportunities for education, jobs and rights for immigrants and minorities

  #############2009#########
  cat('## ICCS 2009  \n')
  index09 <- Itemdesc %>% filter(item != "index") %>% dplyr::select(ICCS_2009) %>% na.omit() %>% pull()
  ds091 <- ISC_cfa %>% filter(!is.na(TOTWGT_Gc2)) %>% 
    dplyr::select(all_of(index09), all_of(Id), IDJK, IDCL, SENWGT_Gc2, SGENDER) %>% 
    mutate(SGENDER = as.character(SGENDER)) 
  ds09 <- ds091 %>% mutate_at(.funs = as.numeric, .vars = index09) 
  survey.design09 <- svydesign(ids=~IDCL, weights=~SENWGT_Gc2, strata = ~IDJK, nest = TRUE, data=ds09)

  cfa09 <- cfa(model09, data = ds09, cluster = c("COUNTRY","IDSCHOOL"), missing = "fiml")
  survey.fit09 <- lavaan.survey(lavaan.fit = cfa09, survey.design = survey.design09, estimator= "MLMVS")
  
  #summary(cfa09, fit.measures=TRUE)
  #print(modindices(cfa09,sort=T)[1:10,])
  p09 <- cbind(ds09, predict(cfa09))
  p09 <- p09 %>% mutate(cycle = "C2") %>% dplyr::select(all_of(Id), all_of(Newscales))
  rm(cfa09)
  
  cnt09 <- unique(ds09$COUNTRY)
  meast09 <- NULL
  stdl09 <- NULL
  for (c09 in cnt09) {
    survey.cnt09 <- svydesign(ids=~IDCL, weights=~SENWGT_Gc2, strata = ~IDJK, nest = TRUE, data=ds09[ds09$COUNTRY == c09,])
    ds09cfa <- ds09 %>%  dplyr::select(all_of(index09), COUNTRY) 
    CNTcfa <- cfa(model09, data = ds09[ds09$COUNTRY == c09,], cluster = "IDSCHOOL")
    survey.CNTfit <- lavaan.survey(lavaan.fit = CNTcfa, survey.design = survey.cnt09, estimator= "MLMVS")
    meas <- fitMeasures(survey.CNTfit, c("chisq","df", "cfi", "tli","rmsea", "srmr"), output = "matrix")
    meas <- rbind(n = nobs(survey.CNTfit), meas)
    meast09 <- cbind(meast09, meas)
    stdl <- standardizedSolution(survey.CNTfit) %>% 
      filter(op == "=~") %>% 
      mutate(cntry = c09)
    stdl09 <- rbind(stdl09, stdl)
  }
  meast09 <- as.data.frame(t(meast09))
  rownames(meast09) <- cnt09
  rm(CNTcfa)
  cat('### CFA - ICCS 2009, all countries')
  cat('  \n')
  cat('  \n')
  meas09 <- fitMeasures(survey.fit09, c("chisq","df","cfi", "tli","rmsea", "srmr"), 
                        output = "matrix")
  knitr::kable(cbind(n = nobs(survey.fit09), round(as.data.frame(t(meas09)), 3))) %>% print() 
  
  cat('  \n')
  cat('### CFA - ICCS 2009, by countries')
  cat('  \n')
  knitr::kable(meast09,digits = 3) %>% print() 
  cat('  \n')
  cat('  \n')
 
  invisible(semPaths(survey.fit09,"model", "std", "lisrel", edge.label.cex = 0.6, intercepts = FALSE, groups = "latent", 
                     pastel = TRUE, title = FALSE, nCharNodes = 10, nDigits = 1))
  title("CFA measurement model", line = 2)
  cat('  \n')
  cat('  \n')
  
  labels <- data.frame(label = tolower(sjlabelled::get_label(ds091))) 
  labels <- labels %>% filter(!str_detect(rownames(labels), c("IDSTUD|IDSCHOOL|COUNTRY|TOTWGT|GENDER"))) %>% 
    mutate(variable = rownames(.))
  stdl09 <- stdl09 %>% mutate(rhs = factor(rhs, levels = labels$variable, labels = labels$label))
  l2 <- stdl09 %>% data.frame() %>% 
  ggplot(aes(x = est.std, y = rhs, color = reorder(cntry, desc(cntry)))) +
    geom_linerange(aes(xmin = ci.lower, xmax = ci.upper), position = position_dodge(0.4)) +
    geom_jitter(position = position_dodge(0.4)) +
    facet_wrap(. ~ lhs, scales = "free", ncol = 1)+
    geom_text(aes(label=cntry),hjust=0, vjust=1, position = position_dodge(0.4), size = 2) +
    theme(legend.position = "none") +
    ggtitle("Loading distribution of scales - ICCS 2009") +
    ylab("") +
    xlab("Loadings with Confidence Interval") +
    scale_y_discrete(labels = function(x) str_wrap(x, 25) )
  print(l2)

  cat('  \n')
  cat('  \n')
  cat('### Invariance between COUNTRY')
  cat('  \n')
  cat('  \n')
  inv.conf09 <- cfa(model09, data = ds09, cluster = "IDSCHOOL", group = "COUNTRY")
  inv.conf09 <- lavaan.survey(lavaan.fit = inv.conf09, survey.design = survey.design09, estimator= "MLMVS")
  inv.metr09 <- cfa(model09, data = ds09, cluster = "IDSCHOOL", group = "COUNTRY", group.equal = c("loadings"))
  inv.metr09 <- lavaan.survey(lavaan.fit = inv.metr09, survey.design = survey.design09, estimator= "MLMVS")
  inv.scal09 <- cfa(model09, data = ds09, cluster = "IDSCHOOL", group = "COUNTRY", group.equal = c("loadings","intercepts"))
  inv.scal09 <- lavaan.survey(lavaan.fit = inv.scal09, survey.design = survey.design09, estimator= "MLMVS")
  inv.stri09 <- cfa(model09, data = ds09, cluster = "IDSCHOOL", group = "COUNTRY", group.equal = c("loadings","intercepts","lv.variances"))
  inv.stri09 <- lavaan.survey(lavaan.fit = inv.stri09, survey.design = survey.design09, estimator= "MLMVS")

  invarCNT <- data.frame(round(rbind(Configural = fitMeasures(inv.conf09, c("npar", "logl","chisq", "df", "tli", "cfi", "rmsea")),
                                  Metric = fitMeasures(inv.metr09, c("npar", "logl","chisq", "df", "tli", "cfi", "rmsea")),
                                  Scalar = fitMeasures(inv.scal09, c("npar", "logl","chisq", "df", "tli", "cfi", "rmsea")),
                                  Strict = fitMeasures(inv.stri09, c("npar", "logl","chisq", "df", "tli", "cfi", "rmsea"))),3))
  invarCNT <- invarCNT %>% mutate(Invariance = rownames(invarCNT)) %>% relocate(Invariance, .before = npar) %>%
    mutate(D_tli = tli-lag(tli),
           D_cfi = cfi-lag(cfi),
           D_rmsea = rmsea-lag(rmsea)) %>%
    knitr::kable() %>% print()
  rm(inv.conf09, inv.metr09, inv.scal09, inv.stri09) #Remove to save space in disk
  cat('  \n')
  cat('  \n')
  cat('### Invariance between GENDER')
  cat('  \n')
  cat('  \n')
  inv.conf09 <- cfa(model09, data = ds09, cluster = "IDSCHOOL", group = "SGENDER")
  inv.conf09 <- lavaan.survey(lavaan.fit = inv.conf09, survey.design = survey.design09, estimator= "MLMVS")
  inv.metr09 <- cfa(model09, data = ds09, cluster = "IDSCHOOL", group = "SGENDER", group.equal = c("loadings"))
  inv.metr09 <- lavaan.survey(lavaan.fit = inv.metr09, survey.design = survey.design09, estimator= "MLMVS")
  inv.scal09 <- cfa(model09, data = ds09, cluster = "IDSCHOOL", group = "SGENDER", group.equal = c("loadings","intercepts"))
  inv.scal09 <- lavaan.survey(lavaan.fit = inv.scal09, survey.design = survey.design09, estimator= "MLMVS")
  inv.stri09 <- cfa(model09, data = ds09, cluster = "IDSCHOOL", group = "SGENDER", group.equal = c("loadings","intercepts","lv.variances"))
  inv.stri09 <- lavaan.survey(lavaan.fit = inv.stri09, survey.design = survey.design09, estimator= "MLMVS")

  invarGNDR <- data.frame(round(rbind(Configural = fitMeasures(inv.conf09, c("npar", "logl","chisq", "df", "tli", "cfi", "rmsea")),
                                     Metric = fitMeasures(inv.metr09, c("npar", "logl","chisq", "df", "tli", "cfi", "rmsea")),
                                     Scalar = fitMeasures(inv.scal09, c("npar", "logl","chisq", "df", "tli", "cfi", "rmsea")),
                                     Strict = fitMeasures(inv.stri09, c("npar", "logl","chisq", "df", "tli", "cfi", "rmsea"))),3))
  invarGNDR <- invarGNDR %>% mutate(Invariance = rownames(invarGNDR)) %>% relocate(Invariance, .before = npar) %>%
    mutate(D_tli = tli-lag(tli),
           D_cfi = cfi-lag(cfi),
           D_rmsea = rmsea-lag(rmsea)) %>%
    knitr::kable() %>% print()
  cat('  \n')
  cat('  \n')
  rm(inv.conf09, inv.metr09, inv.scal09, inv.stri09) #Remove to save space in disk
}
if (any(grepl("16", years$year))){
  if(length(Newscales) == 3){
    model16<-'
      Gend_Equal =~ IS3G24A + IS3G24B + IS3G24C + IS3G24D + IS3G24E + IS3G24F
      Immi_Equal =~ ES3G04A + ES3G04B + ES3G04C + ES3G04D + ES3G04E
      Ethn_Equal =~ IS3G25A + IS3G25B + IS3G25C + IS3G25D + IS3G25E
      IS3G24A ~~ IS3G24B
      IS3G25A ~~ IS3G25B
      ES3G04A ~~ ES3G04D
    '
    modelLA16<-'
      Gend_Equal =~ IS3G24A + IS3G24B + IS3G24C + IS3G24D + IS3G24E + IS3G24F
      Ethn_Equal =~ IS3G25A + IS3G25B + IS3G25C + IS3G25D + IS3G25E
      IS3G24D ~~ IS3G24F
      IS3G24C ~~ IS3G24D
      IS3G24C ~~ IS3G24F
    '
   } else if(length(Newscales) == 6){
      model16<-'
        EqOppoWom =~ IS3G24A + IS3G24B + IS3G24E
        PolParWom =~ IS3G24C + IS3G24D + IS3G24F
        Lifestyle =~ ES3G04A + ES3G04D 
        PolParImm =~ ES3G04C + IS3G25D 
        EqOppImMi =~ IS3G25A + IS3G25B + IS3G25C + ES3G04B + ES3G04E
        IS3G25A ~~ IS3G25B
      '
      modelLA16<-'
        EqOppoWom =~ IS3G24A + IS3G24B + IS3G24E
        PolParWom =~ IS3G24C + IS3G24D + IS3G24F
        EqOppEthn =~ IS3G25A + IS3G25B + IS3G25C + IS3G25D
        IS3G25A ~~ IS3G25B
      '
    }
  # EqOppoWom : Equal opportunities and rightf for woman
  # PolParWom : Equal participation in jobs and politics for woman
  # Lifestyle : Immigrant should maintain lifestyle and language
  # PolParImm : Equal participation in politics for immigrants
  # EqOppImMi : Equal opportunities for education, jobs and rights for immigrants and minorities
  
  #############2016#########
  cat('## ICCS 2016  \n')
  cat('  \n')
  index16 <- Itemdesc %>% filter(item != "index") %>% dplyr::select(ICCS_2016) %>% na.omit() %>% pull()
  ds161 <- ISC_cfa %>% filter(!is.na(TOTWGT_Gc3)) %>% 
    dplyr::select(all_of(index16), all_of(Id), all_of(sampleID), SENWGT_Gc3, S_GENDER) %>% 
    mutate(S_GENDER = as.character(S_GENDER)) 
  ds16 <- ds161 %>% mutate_at(.funs = as.numeric, .vars = index16) 
  
  ds16E <- ds16 %>% filter(!COUNTRY %in% c("CHL", "COL", "DOM", "MEX"))
  survey.design16E <- svydesign(ids = ~ IDCL, weights=~SENWGT_Gc3, strata = ~ IDJK, nest = TRUE, data=ds16E)
  cfa16E <- cfa(model16, data = ds16E, cluster = c("COUNTRY","IDSCHOOL"), missing = "fiml")
  survey.fit16E <- lavaan.survey(lavaan.fit = cfa16E, survey.design = survey.design16E, estimator= "MLMVS")
  #summary(cfa16E, fit.measures=TRUE)
  #print(modindices(cfa16E,sort=T)[1:10,])
  
  ds16LA <- ds16 %>% filter(COUNTRY %in% c("CHL", "COL", "DOM", "MEX"))
  survey.design16LA <- svydesign(ids=~IDCL, weights=~SENWGT_Gc3, strata = ~ IDJK, nest = TRUE, data=ds16LA)
  cfa16LA <- cfa(modelLA16, data = ds16LA, cluster = c("COUNTRY","IDSCHOOL"), missing = "fiml")
  survey.fit16LA <- lavaan.survey(lavaan.fit = cfa16LA, survey.design = survey.design16LA, estimator= "MLMVS")
  #summary(cfa16LA, fit.measures=TRUE)
  #print(modindices(cfa16LA,sort=T)[1:10,])
  
  p16E <- cbind(ds16E, predict(cfa16E))
  p16LA <- cbind(ds16LA, predict(cfa16LA))
  p16 <- p16E %>% bind_rows(p16LA) %>% mutate(cycle = "C3") %>% 
    dplyr::select(all_of(Id), all_of(Newscales))
  rm(cfa16E, cfa16LA)
  
  cnt16 <- unique(ds16$COUNTRY)
  meast16 <- NULL
  stdl16 <- NULL
  for (c16 in cnt16) {
    survey.cnt16 <- svydesign(ids=~IDCL, weights=~SENWGT_Gc3, strata = ~ IDJK, nest = TRUE, data=ds16[ds16$COUNTRY == c16,])
    if (c16 %in% c("CHL", "COL", "DOM", "MEX")){
      CNTcfa <- cfa(modelLA16, data = ds16[ds16$COUNTRY == c16,], cluster = "IDSCHOOL")
      survey.CNTfit <- lavaan.survey(lavaan.fit = CNTcfa, survey.design = survey.cnt16, estimator= "MLMVS")
      meas <- fitMeasures(survey.CNTfit, c("chisq","df", "cfi", "tli","rmsea", "srmr"), output = "matrix")
      meas <- rbind(n = nobs(survey.CNTfit), meas)
      meast16 <- cbind(meast16, meas)
      stdl <- standardizedSolution(survey.CNTfit) %>% 
        filter(op == "=~") %>% 
        mutate(cntry = c16)
      stdl16 <- rbind(stdl16, stdl)
    } else {
      CNTcfa <- cfa(model16, data = ds16[ds16$COUNTRY == c16,], cluster = "IDSCHOOL")
      survey.CNTfit <- lavaan.survey(lavaan.fit = CNTcfa, survey.design = survey.cnt16, estimator= "MLMVS")
      meas <- fitMeasures(survey.CNTfit, c("chisq","df", "cfi", "tli","rmsea", "srmr"), output = "matrix")
      meas <- rbind(n = nobs(survey.CNTfit), meas)
      meast16 <- cbind(meast16, meas)
      stdl <- standardizedSolution(survey.CNTfit) %>% 
        filter(op == "=~") %>% 
        mutate(cntry = c16)
      stdl16 <- rbind(stdl16, stdl)
    }

  }
  meast16 <- as.data.frame(t(meast16))
  rownames(meast16) <- cnt16
  rm(CNTcfa)
  
  cat('### CFA - ICCS 2016, all countries')
  cat('  \n')
  cat('  \n')
  tmeasE <- t(fitMeasures(survey.fit16E, c("chisq","df","cfi", "tli","rmsea", "srmr"), 
              output = "matrix"))
  tmeasLA <- t(fitMeasures(survey.fit16LA, c("chisq","df","cfi", "tli","rmsea", "srmr"), 
                         output = "matrix"))
  meas16 <- rbind(data.frame(Quest = "Europe", n = nobs(survey.fit16E), round(tmeasE, 3)),
                  data.frame(Quest = "Latam", n = nobs(survey.fit16LA), round(tmeasLA, 3)))
  knitr::kable(meas16) %>% print() 
  
  cat('  \n')
  cat('### CFA - ICCS 2016, by countries')
  cat('  \n')
  knitr::kable(meast16, digits = 3) %>% print() 
  cat('  \n')
  cat('  \n')
  #print(modindices(survey.fit16,sort=T)[1:10,])
  invisible(semPaths(survey.fit16E,"model", "std", "lisrel", edge.label.cex = 0.6, intercepts = FALSE, groups = "latent", 
                     pastel = TRUE, title = FALSE, nCharNodes = 10, nDigits = 1))
  title("CFA measurement model Europe", line = 2)
  cat('  \n')
  cat('  \n')
  invisible(semPaths(survey.fit16LA,"model", "std", "lisrel", edge.label.cex = 0.6, intercepts = FALSE, groups = "latent", 
                     pastel = TRUE, title = FALSE, nCharNodes = 10, nDigits = 1))
  title("CFA measurement model Latin America", line = 2)
  cat('  \n')
  cat('  \n')
  
  labels <- data.frame(label = tolower(sjlabelled::get_label(ds161))) 
  labels <- labels %>% filter(!str_detect(rownames(labels), c("IDSTUD|IDSCHOOL|COUNTRY|TOTWGT|GENDER"))) %>% 
    mutate(variable = rownames(.),
           label = str_remove(label, "rights and responsibilities/rights and responsibilities/|rights and responsibilities/roles women and men/|moving/"))
  stdl16 <- stdl16 %>% mutate(rhs = factor(rhs, levels = labels$variable, labels = labels$label))
  l3 <- stdl16 %>% data.frame() %>% 
    ggplot(aes(x = est.std, y = rhs, color = reorder(cntry, desc(cntry)))) +
    geom_linerange(aes(xmin = ci.lower, xmax = ci.upper), position = position_dodge(0.4)) +
    geom_jitter(position = position_dodge(0.4)) +
    facet_wrap(. ~ lhs, scales = "free", ncol = 1)+
    geom_text(aes(label=cntry),hjust=0, vjust=1, position = position_dodge(0.4), size = 2) +
    theme(legend.position = "none") +
    ggtitle("Loading distribution of scales - ICCS 2016") +
    ylab("") +
    xlab("Loadings with Confidence Interval") +
    scale_y_discrete(labels = function(x) str_wrap(x, 30)) +
    scale_x_continuous(breaks = c(0, 0.25, 0.5, 0.75, 1), limits = c(0,1))
  print(l3)
  cat('  \n')
  cat('  \n')
  cat('### Invariance between COUNTRY')
  cat('  \n')
  cat('  \n')

  inv.conf16 <- cfa(modelLA16, data = ds16LA, cluster = "IDSCHOOL", group = "COUNTRY")
  inv.conf16 <- lavaan.survey(lavaan.fit = inv.conf16, survey.design = survey.design16LA, estimator= "MLMVS")
  inv.metr16 <- cfa(modelLA16, data = ds16LA, cluster = "IDSCHOOL", group = "COUNTRY", group.equal = c("loadings"))
  inv.metr16 <- lavaan.survey(lavaan.fit = inv.metr16, survey.design = survey.design16LA, estimator= "MLMVS")
  inv.scal16 <- cfa(modelLA16, data = ds16LA, cluster = "IDSCHOOL", group = "COUNTRY", group.equal = c("loadings","intercepts"))
  inv.scal16 <- lavaan.survey(lavaan.fit = inv.scal16, survey.design = survey.design16LA, estimator= "MLMVS")
  inv.stri16 <- cfa(modelLA16, data = ds16LA, cluster = "IDSCHOOL", group = "COUNTRY", group.equal = c("loadings","intercepts","lv.variances"))
  inv.stri16 <- lavaan.survey(lavaan.fit = inv.stri16, survey.design = survey.design16LA, estimator= "MLMVS")
  invarCNT2 <- data.frame(Quest = "Latam", round(rbind(Configural = fitMeasures(inv.conf16, c("npar", "logl","chisq", "df", "tli", "cfi", "rmsea")),
                                     Metric = fitMeasures(inv.metr16, c("npar", "logl","chisq", "df", "tli", "cfi", "rmsea")),
                                     Scalar = fitMeasures(inv.scal16, c("npar", "logl","chisq", "df", "tli", "cfi", "rmsea")),
                                     Strict = fitMeasures(inv.stri16, c("npar", "logl","chisq", "df", "tli", "cfi", "rmsea"))),3))

  ds16E <- ds16 %>% filter(!COUNTRY %in%  c("CHL", "COL", "PER", "DOM", "MEX"))
  inv.conf16 <- cfa(model16, data = ds16E, cluster = "IDSCHOOL", group = "COUNTRY")
  inv.conf16 <- lavaan.survey(lavaan.fit = inv.conf16, survey.design = survey.design16E, estimator= "MLMVS")
  inv.metr16 <- cfa(model16, data = ds16E, cluster = "IDSCHOOL", group = "COUNTRY", group.equal = c("loadings"))
  inv.metr16 <- lavaan.survey(lavaan.fit = inv.metr16, survey.design = survey.design16E, estimator= "MLMVS")
  inv.scal16 <- cfa(model16, data = ds16E, cluster = "IDSCHOOL", group = "COUNTRY", group.equal = c("loadings","intercepts"))
  inv.scal16 <- lavaan.survey(lavaan.fit = inv.scal16, survey.design = survey.design16E, estimator= "MLMVS")
  inv.stri16 <- cfa(model16, data = ds16E, cluster = "IDSCHOOL", group = "COUNTRY", group.equal = c("loadings","intercepts","lv.variances"))
  inv.stri16 <- lavaan.survey(lavaan.fit = inv.stri16, survey.design = survey.design16E, estimator= "MLMVS")
  invarCNT1 <- data.frame(Quest = "Europe", round(rbind(Configural = fitMeasures(inv.conf16, c("npar", "logl","chisq", "df", "tli", "cfi", "rmsea")),
                                     Metric = fitMeasures(inv.metr16, c("npar", "logl","chisq", "df", "tli", "cfi", "rmsea")),
                                     Scalar = fitMeasures(inv.scal16, c("npar", "logl","chisq", "df", "tli", "cfi", "rmsea")),
                                     Strict = fitMeasures(inv.stri16, c("npar", "logl","chisq", "df", "tli", "cfi", "rmsea"))),3))

  invarCNT <- invarCNT1 %>% mutate(Invariance = rownames(invarCNT1))  %>% relocate(Invariance, .before = npar) %>%
    mutate(D_tli = tli-lag(tli),
           D_cfi = cfi-lag(cfi),
           D_rmsea = rmsea-lag(rmsea)) %>%
    bind_rows(invarCNT2 %>% mutate(Invariance = rownames(invarCNT2))  %>% relocate(Invariance, .before = npar) %>%
    mutate(D_tli = tli-lag(tli),
           D_cfi = cfi-lag(cfi),
           D_rmsea = rmsea-lag(rmsea))) %>%
    knitr::kable() %>% print()
  rm(inv.conf16, inv.metr16, inv.scal16, inv.stri16) #Remove to save space in disk
  cat('  \n')
  cat('  \n')
  cat('### Invariance between GENDER')
  cat('  \n')
  cat('  \n')
  inv.conf16 <- cfa(modelLA16, data = ds16LA, cluster = "IDSCHOOL", group = "S_GENDER")
  inv.conf16 <- lavaan.survey(lavaan.fit = inv.conf16, survey.design = survey.design16LA, estimator= "MLMVS")
  inv.metr16 <- cfa(modelLA16, data = ds16LA, cluster = "IDSCHOOL", group = "S_GENDER", group.equal = c("loadings"))
  inv.metr16 <- lavaan.survey(lavaan.fit = inv.metr16, survey.design = survey.design16LA, estimator= "MLMVS")
  inv.scal16 <- cfa(modelLA16, data = ds16LA, cluster = "IDSCHOOL", group = "S_GENDER", group.equal = c("loadings","intercepts"))
  inv.scal16 <- lavaan.survey(lavaan.fit = inv.scal16, survey.design = survey.design16LA, estimator= "MLMVS")
  inv.stri16 <- cfa(modelLA16, data = ds16LA, cluster = "IDSCHOOL", group = "S_GENDER", group.equal = c("loadings","intercepts","lv.variances"))
  inv.stri16 <- lavaan.survey(lavaan.fit = inv.stri16, survey.design = survey.design16LA, estimator= "MLMVS")

  invarGNDR2 <- data.frame(Quest = "Latam",round(rbind(Configural = fitMeasures(inv.conf16, c("npar", "logl","chisq", "df", "tli", "cfi", "rmsea")),
                                      Metric = fitMeasures(inv.metr16, c("npar", "logl","chisq", "df", "tli", "cfi", "rmsea")),
                                      Scalar = fitMeasures(inv.scal16, c("npar", "logl","chisq", "df", "tli", "cfi", "rmsea")),
                                      Strict = fitMeasures(inv.stri16, c("npar", "logl","chisq", "df", "tli", "cfi", "rmsea"))),3))

  inv.conf16 <- cfa(model16, data = ds16E, cluster = "IDSCHOOL", group = "S_GENDER")
  inv.conf16 <- lavaan.survey(lavaan.fit = inv.conf16, survey.design = survey.design16E, estimator= "MLMVS")
  inv.metr16 <- cfa(model16, data = ds16E, cluster = "IDSCHOOL", group = "S_GENDER", group.equal = c("loadings"))
  inv.metr16 <- lavaan.survey(lavaan.fit = inv.metr16, survey.design = survey.design16E, estimator= "MLMVS")
  inv.scal16 <- cfa(model16, data = ds16E, cluster = "IDSCHOOL", group = "S_GENDER", group.equal = c("loadings","intercepts"))
  inv.scal16 <- lavaan.survey(lavaan.fit = inv.scal16, survey.design = survey.design16E, estimator= "MLMVS")
  inv.stri16 <- cfa(model16, data = ds16E, cluster = "IDSCHOOL", group = "S_GENDER", group.equal = c("loadings","intercepts","lv.variances"))
  inv.stri16 <- lavaan.survey(lavaan.fit = inv.stri16, survey.design = survey.design16E, estimator= "MLMVS")

  invarGNDR1 <- data.frame(Quest = "Europe", round(rbind(Configural = fitMeasures(inv.conf16, c("npar", "logl","chisq", "df", "tli", "cfi", "rmsea")),
                                  Metric = fitMeasures(inv.metr16, c("npar", "logl","chisq", "df", "tli", "cfi", "rmsea")),
                                  Scalar = fitMeasures(inv.scal16, c("npar", "logl","chisq", "df", "tli", "cfi", "rmsea")),
                                  Strict = fitMeasures(inv.stri16, c("npar", "logl","chisq", "df", "tli", "cfi", "rmsea"))),3))
  invarGNDR <- invarGNDR1 %>% mutate(Invariance = rownames(invarGNDR1)) %>% relocate(Invariance, .before = npar) %>%
    mutate(D_tli = tli-lag(tli),
           D_cfi = cfi-lag(cfi),
           D_rmsea = rmsea-lag(rmsea)) %>%
    bind_rows(invarGNDR2 %>% mutate(Invariance = rownames(invarGNDR2)) %>% relocate(Invariance, .before = npar) %>%
    mutate(D_tli = tli-lag(tli),
           D_cfi = cfi-lag(cfi),
           D_rmsea = rmsea-lag(rmsea))) %>%
    knitr::kable() %>% print()
  cat('  \n')
  cat('  \n')
  rm(inv.conf16, inv.metr16, inv.scal16, inv.stri16) #Remove to save space in disk
}

cat('  \n')
cat('  \n')
cat('## Summary indexes, all countries, all cycles')
cat('  \n')
cat('  \n')

pall <- plyr::rbind.fill(p99, p09, p16)
ISC_cfa <- left_join(ISC_cfa, pall, by = all_of(Id)) 


mg <- ISC_cfa %>% dplyr::select(cycle, all_of(Newscales)) %>% group_by(cycle) %>% 
  summarise_at(Newscales, list(~ mean(., na.rm = TRUE))) %>% 
  mutate(cycle = as.factor(cycle)) %>% data.frame()

for(i in 1:length(Newscales)){
  
  if (length(Newscales) == 3){
    set_label(ISC_cfa$Gend_Equal) <- c("Attitudes towards Gender equality")
    set_label(ISC_cfa$Immi_Equal) <- c("Attitudes towards Immigrants rights")
    set_label(ISC_cfa$Ethn_Equal) <- c("Attitudes towards Minorities rights")
  } else if (length(Newscales) == 5){
    set_label(ISC_cfa$EqOppoWom) <- c("Equal opportunities and rights for women")
    set_label(ISC_cfa$PolParWom) <- c("Equal participation in jobs and politics for women")
    set_label(ISC_cfa$Lifestyle) <- c("Immigrant should maintain lifestyle and language")
    set_label(ISC_cfa$PolParImm) <- c("Equal participation in politics for immigrants")
    set_label(ISC_cfa$EqOppImMi) <- c("Equal opportunities for education, jobs and rights for immigrants and minorities")
    set_label(ISC_cfa$EqOppEthn) <- c("Equal opportunities for education, jobs and rights for minorities")
  } else if (length(Newscales) == 4){
    set_label(ISC_cfa$EqOppoWom) <- c("Equal opportunities and rights for women")
    set_label(ISC_cfa$PolParWom) <- c("Equal participation in jobs and politics for women")
    set_label(ISC_cfa$EqOppEthn) <- c("Equal opportunities for minorities")
  }
  
  vargra <- Newscales[i]
  s2 <- ISC_cfa %>% dplyr::select("cycle", "COUNTRY", vargra) %>% na.omit() %>% 
    ggplot(aes_string(x = vargra, y = paste0("reorder(COUNTRY, desc(COUNTRY))"), group = paste0("interaction(cycle, COUNTRY)"), fill = "COUNTRY")) +
    geom_boxplot() +
    facet_grid(.~ cycle)+
    geom_vline(aes_string(xintercept = vargra), mg, linetype="dotted", size = 0.8) +
    ggtitle(eval(parse(text=paste0("attributes(ISC_cfa$",vargra,")$label")))) +
    ylab("Distribution of Scores CFA") +
    xlab(paste0(vargra)) +
    scale_color_brewer(palette="Accent") +
    theme(legend.position = "none")
  print(s2)
}
ISC_cfa <- ISC_cfa %>% select(all_of(Id), all_of(Scales), all_of(Newscales))
