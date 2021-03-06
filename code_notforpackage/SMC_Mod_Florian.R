#' SMC sampler
#'
#' @param likelihood likelihood function (or posterior if the initial sample is not the posterior)
#' @param initialParticles initial particles
#' @param iterations number of iterations
#' @param resampling if new particles should be created at each iteration
#' @export
smc_sampler_mod <- function(likelihood,prior=NULL, initialParticles, iterations = 4, resampling = T, proposal = NULL, parallel=F,setup=NULL,clustertype="SOCK",numCores=1,parameters,scaled,originalvalues,Logtype){
  if (is.null(prior)){
    prior <- function(x){
      return(0)
    }
  }

  if (parallel == T) {
    warning("cluster in parallel not implemented yet, no speedup from parallel option")
    parallelLikelihood <- generateParallelExecuter(likelihood)
  }

  # calculates the likelihood for a number of particles
  getLikelihood <- function(particles){
    parameters<-data.frame(names,particles)
    names(parameters)<-c("names",rep("values",ncol(particles)))
    parameters$names<-as.character(parameters$names)
    if (parallel == "external") likelihoodParallel(setup,clustertype,numCores,parameters,scaled,originalvalues,Logtype)
    else if (parallel == T) parallelLikelihood(particles)
    else apply(particles, 1, likelihood)
  }

  getPrior<- function(particles){
    apply(particles, 2, prior)
  }

  if (is.null(proposal)) proposal <- function(x) rnorm(length(x), mean = x, sd = 0.2)

  particles <- initialParticles

  numPar <- nrow(initialParticles)

  for (i in 1:iterations){
    print(paste(i," out of ", iterations, " iterations.",sep=""))

    likelihoodValues <- getLikelihood(particles)
    likelihoodValues[which(is.na(likelihoodValues))]<- -1e6
    pdf(paste(i," out of ", iterations, " iterations ", Sys.Date(),".pdf",sep=""))
    plot(likelihoodValues,main = paste(i," out of ", iterations, " iterations.",sep=""))
    dev.off()

    relativeL = exp((likelihoodValues) - max(likelihoodValues, na.rm = T)) ^(1/iterations)

    sel = sample.int(n=length(likelihoodValues), size = length(likelihoodValues), replace = T, prob = relativeL)
    # print(sel)
    particles = particles[,sel]

    if (numPar == 1) particles = matrix(particles, ncol = 1)

    if (resampling == T){

      if (numPar == 1) particlesProposals = matrix(apply(particles, 1, proposal), ncol = 1)
      else particlesProposals = t(apply(particles, 1, proposal))

      jumpProb<-matrix(nrow=ncol(particlesProposals))
      not_valid<-unique(ceiling(which(particlesProposals< 0)/numPar))
      jumpProb[not_valid]<-0

      valid<-which(is.na(jumpProb))
      jumpProb[valid] <- exp(getLikelihood(data.frame(particlesProposals[,valid])) - likelihoodValues[sel[valid]])^(i/iterations) * exp(getPrior(data.frame(particlesProposals[,valid]))- getPrior(data.frame(particles[,valid])))
      jumpProb[is.na(jumpProb)]<-0

      accepted <- jumpProb > runif(length(jumpProb), 0 ,1)

      particles[,accepted ] = particlesProposals[,accepted]
    }
  }
  return(c(particles,likelihoodValues))
}

