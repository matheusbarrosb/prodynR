#' Stochastic Monte Carlo simulation to estimate cohort biomass trajectories
#'
#' Incorporates uncertainty in population rates in biomass output
#' @param GR.mu Mean fish growth rate during the juvenile phase (mm/day)
#' @param GR.sd SD of fish growth rate during the juvenile phase (mm/day)
#' @param N0.mu Mean initial number of fish in the cohort 
#' @param N0.sd SD of initial number of fish in the cohort 
#' @param M_ref.mu Mean reference mortality rate (yr-1)
#' @param M_ref.sd SD of reference mortality rate (yr-1)
#' @param L_ref.mu Mean reference size at which M = M_ref (in mm)
#' @param L_ref.sd SD of reference size at which M = M_ref (in mm)
#' @param Lm.mu Mean size at maturity (mm)
#' @param Lm.sd SD of size at maturity (mm)
#' @param K.mu Mean von Bertalanffy growth rate (yr-1)
#' @param K.sd SD of von Bertalanffy growth rate (yr-1)
#' @param Linf.mu Mean von Bertalanffy asymptotic size (mm)
#' @param Linf.sd SD of von Bertalanffy asymptotic size (mm)
#' @param t0.mu Mean von Bertalanffy theoretical age at length zero (unitless)
#' @param t0.sd SD of von Bertalanffy theoretical age at length zero (unitless)
#' @param lwa.mu Mean intercept of length-weight relationship in the form W = aL^b
#' @param lwa.sd SD of intercept of length-weight relationship in the form W = aL^b
#' @param lwb.mu Mean slope of length-weight relationship in the form W = aL^b
#' @param lwb.sd SD of slope of length-weight relationship in the form W = aL^b
#' @param L0.mu Mean initial size / size at hatching (mm)
#' @param L0.sd SD of initial size / size at hatching (mm)
#' @param N Number of Monte Carlo iterations
#' @param plot Logical ('TRUE' or 'FALSE')
#' @param N_years Number of time steps to project the cohort (in years) 
#' @param progress Logical ('TRUE' or 'FALSE') whether to display progress bar
#' @param output.type If = "complete", function displays complete cohort trajectories
#' @return Simulated biomass trajectories with upper and lower bounds, accumulated biomass
#' @examples
#' stoch_P(GR.mu = 0.45, GR.sd = 0.03, N0.mu = 1, N0.sd = 0.01, 
#' M_ref.mu = 1.6, M_ref.sd = 0.01, L_ref.mu = 120, L_ref.sd = 5,
#' Lm.mu = 120, Lm.sd = 0, K.mu = 0.33, K.sd = 0.05, Linf.mu = 200,
#' Linf.sd = 30, t0.mu = 0, t0.sd = 0, lwa.mu = 0.005,
#' lwa.sd = 0.0001, lwb.mu = 3.25, lwb.sd = 0.06,
#' L0.mu = 30, L0.sd = 0, N = 1000, N_years = 10,
#' progress = "TRUE", output.type = "complete", juvGrowthType = "linear)
#' @export
stoch_P <- function(GR.mu = NULL, GR.sd = NULL,
                    N0.mu = NULL, N0.sd = NULL,
                    M_ref.mu = NULL, M_ref.sd = NULL,
                    L_ref.mu = NULL, L_ref.sd = NULL,
                    Lm.mu = NULL, Lm.sd = NULL,
                    K.mu = NULL, K.sd = NULL,
                    Linf.mu = NULL, Linf.sd = NULL,
                    t0.mu = NULL, t0.sd = NULL,
                    lwa.mu = NULL, lwa.sd = NULL,
                    lwb.mu = NULL, lwb.sd = NULL,
                    L0.mu = NULL, L0.sd = NULL,
                    t.steps = NULL, N = 100,
                    plot = FALSE, N_years = NULL,
                    progress = "TRUE", output.type = "complete",
                    juvGrowthType = "linear") {
  
  # set error and warning messages
  if (GR.mu <= 0)       {stop("Growth rate (GR) must be a positive number")}
  if (N0.mu <= 0)       {stop("Initial abundance (N0) must be a positive number")}
  if (M_ref.mu <= 0)    {stop("Reference mortality (M_ref) must be a positive number")}
  if (L_ref.mu <= 0)    {stop("Reference length (L_ref) must be a positive number")}
  if (Lm.mu <= 0)       {stop("Length at maturity (Lm) must be a positive number")}
  if (K.mu <= 0)        {stop("von Bertalanffy growth rate must be a positive number")}
  if (Linf.mu <= 0)     {stop("von Bertalanffy asymptotic length must be a positive number")}
  if (Linf.mu <= Lm.mu) {stop("Length at maturity (Lm) must be smaller than Linf")}
  if (is.null(lwa.mu) & is.null(lwb.mu)) {
    lwa.mu <- 0.001; lwb.mu = 3
    warning("Length-weight parameters not provided: the simulation is assuming isometry")
  }
  if (L0.mu <= 0)       {stop("Initial size (L0) must be a positive number")}
  if (L0.mu > Lm.mu)    {stop("Initial size (L0) must be smaller than length at maturity (Lm)")}
  
  set.seed(13) # random number generator. Do not modify, that ensures
  # reproducible results
  
  # create a data frame with distributions of input parameters to be looped over
  prior.df <- data.frame(
                         rnorm(N, GR.mu, GR.sd),
                         rnorm(N, N0.mu, N0.sd),
                         rnorm(N, M_ref.mu, M_ref.sd),
                         rnorm(N, L_ref.mu, L_ref.sd),
                         rnorm(N, Lm.mu, Lm.sd),
                         rnorm(N, K.mu, K.sd),
                         rnorm(N, Linf.mu, Linf.sd),
                         rnorm(N, t0.mu, t0.sd),
                         rnorm(N, lwa.mu, lwa.sd),
                         rnorm(N, lwb.mu, lwb.sd),
                         rnorm(N, L0.mu, L0.sd)
                         )
  
  names(prior.df) <- c('GR', 'N0', 'M_ref', 'L_ref', 'Lm', 'K', 'Linf', 't0', 'lwa', 'lwb', 'L0')
  
  out.df <- NULL # create empty object to store pred_B results
  
  pb <- txtProgressBar(min = 0, max = N, style = 3, char = "-")
  
  for(i in 1:N) { # Monte Carlo procedure: loop over input parameter 
                  # distributions N times and collect results
    
    if (juvGrowthType == "linear") {
    
      out <- pred_B(GR = prior.df$GR[i],
                    N0 = prior.df$N0[i],
                    M_ref = prior.df$M_ref[i],
                    L_ref = prior.df$L_ref[i],
                    Lm = prior.df$Lm[i],
                    K = prior.df$K[i],
                    Linf = prior.df$Linf[i],
                    t0 = prior.df$t0[i],
                    a = prior.df$lwa[i],
                    b = prior.df$lwb[i],
                    L0 = prior.df$L0[i],
                    t.steps = 365*N_years, juvGrowthType = "linear")
      
    
    out.df <- cbind(out.df, out$sim_values$GP, deparse.level = 0)
    
    } else if (juvGrowthType == "VB") {
      
      out <- pred_B(GR = prior.df$GR[i],
                    N0 = prior.df$N0[i],
                    M_ref = prior.df$M_ref[i],
                    L_ref = prior.df$L_ref[i],
                    Lm = prior.df$Lm[i],
                    K = prior.df$K[i],
                    Linf = prior.df$Linf[i],
                    t0 = prior.df$t0[i],
                    a = prior.df$lwa[i],
                    b = prior.df$lwb[i],
                    L0 = prior.df$L0[i],
                    t.steps = 365*N_years, juvGrowthType = "VB")
      
      
      out.df <- cbind(out.df, out$sim_values$GP, deparse.level = 0)
      
    }
    
    if (progress == "TRUE") {
      setTxtProgressBar(pb, i)
    }
  }
  
  close(pb)
  
  Bacc.mu  <- apply(out.df, 1, mean, na.rm = TRUE)
  Bacc.up  <- apply(out.df, 1, quantile, probs = c(.8), na.rm = TRUE)
  Bacc.low <- apply(out.df, 1, quantile, probs = c(.2), na.rm = TRUE)
  
  Bacc.out <- data.frame(Bacc.mu, Bacc.low, Bacc.up) # df with integrated biomass trajectories
  GP       <- c(max(Bacc.mu), max(Bacc.low), max(Bacc.up)) # accumulated biomass
  names(Bacc.out) <- c("Mean", "Lower", "Upper")
  names(GP)       <- c("Mean", "Lower", "Upper")
  
  if (output.type == "complete") {
    output <- list(GP, Bacc.out) # main function output
    
    par(mfrow = c(1,2))
    
    plot(Bacc.mu, type = "l", lty = 1,
         lwd = 1.5, ylim = c(0,max(Bacc.up)),
         xlab = "Time (days)", ylab = "Gross production",
         main = "Biomass over time")
    lines(Bacc.low, lty = 3)
    lines(Bacc.up,  lty = 3)
    
    plot(density(rnorm(N, mean = GP[1], sd = (GP[3] - GP[2])/3.92)),
         main = "Gross biomass production", col = "black",
         ylab = "Probability density", xlab = "GP")
    abline(v = GP[1], col="red", lwd=2, lty=2)
    legend("topleft", legend=c("Mean"),
           col=c("red"), lty=2, cex=0.8)
    
  } else {output <- GP}
  
  return(output)
  
} # end of function
