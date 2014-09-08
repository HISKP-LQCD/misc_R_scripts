construct.empty.hadron_obs <- function() {
  hadron_obs <- list()
  attr(hadron_obs,"class") <- c("hadron_obs",class(hadron_obs))
  hadron_obs
}

construct.hadron_obs <- function(name,texlabel,m.sea,m.val,mean,err,boot) {
  hadron_obs <- construct.empty.hadron_obs()
  hadron_obs[[1]] <- list( name=name, texlabel=texlabel, m.sea=m.sea, m.val=m.val,
                          mean=mean, err=err, boot=boot )
}
  
select.hadron_obs <- function(hadron_obs,by,filter) {
  if(!any(class(hadron_obs) == "hadron_obs")) {
    stop("select.hadron_obs: hadron_obs argument must be of class hadron_obs!\n")
  }
  rval <- list()
  for( i in hadron_obs ) {
    if( i[[by]] == filter )
      rval[[(length(rval)+1)]] <- i
  }
  attr(rval,"class") <- class(hadron_obs)
  rval
}

as.data.frame.hadron_obs <- function(hadron_obs) {
  if(!any(class(hadron_obs) == "hadron_obs")) {
   stop("as.data.frame.hadron_obs: hadron_obs argument must be of class hadron_obs!\n")
  }
}

# hadron_obs should already have been filtered to contain
# only one consistent observable
# pred.idx is a list of two index vecors which specify the
# predictor variables to be used for fitting the model later on

extract.for.fes_fit <- function(hadron_obs, pred.idx) {
  if(!any(class(hadron_obs) == "hadron_obs")) {
   stop("preapre.for.fes_fit: hadron_obs argument must be of class hadron_obs!\n")
  }
  n.boot <- length(hadron_obs[[1]]$boot)
  # number of predictor variables
  n.pred <- length(pred.idx$m.sea)+length(pred.idx$m.val)
  pred.names <- sprintf("x%d",1:n.pred)
  # number of response points
  n.resp <- length(hadron_obs)
  
  rval <- vector(mode="list", length=n.boot)

  # pre-allocate memory
  for( i in 1:n.boot ) {
    rval[[i]] <- as.data.frame( array(dim=c(n.resp,n.pred+2),
                                      dimnames=list(c(NULL),c("y",pred.names,"weight"))))
  }
  
  # construct the list of response variables with their predictors and weights
  # for weighted ChiSqr
  # at some point in the future one could actually consider a full covariance matrix
  # here!
  for( b in 1:n.boot ) {
    for( r in 1:n.resp ) {
      rval[[b]][r,] <- c(hadron_obs[[r]]$boot[b],
                         hadron_obs[[r]]$m.val[pred.idx$m.val],
                         hadron_obs[[r]]$m.sea[pred.idx$m.sea],
                         1/hadron_obs[[r]]$err^2)
    }
  }
  rval
}

# a bit like above but extracts values and errors only
# assumes that hadron_obs already contains a consistent observable
# x.name specifies the list member which corresponds to the x variable ('m.val' or 'm.sea', currently)
# x.idx specifies the element of that list member which should be used as
# the x variable, this could be '2', say

extract.for.plot <- function(hadron_obs,x.name,x.idx) {
  N <- length(hadron_obs)
  rval <- as.data.frame( array(dim=c(N,3), dimnames=list(c(NULL),c("y","dy","x"))))
  for( i in 1:N ) {
    rval[i,] <-  c(y=hadron_obs[[i]]$mean,dy=hadron_obs[[i]]$err,x=hadron_obs[[i]][[x.name]][x.idx])
  }
  rval
}

# function which will produce a plot of data extracted from a hadron_obs object
# a number of optional items can be added to the plot
plot.hadron_obs <- function(df,name,pheno,extrapolations,solutions,lg,debug=FALSE,...) {
  require(tikzDevice)
  texfile <- sprintf("%s.tex",name) 
  pdffile <- sprintf("%s.pdf",name)
  tikz(texfile, standAlone = TRUE, width=4, height=4)

  
  if(debug){
    cat("Supllied data points\n")
    print(df)
  }
  
  # set up plot
  plotwitherror( y=df$y, x=df$x, dy=df$dy, type='n', ... )
  
  # extract plot boundaries
  lims <- par("usr")
  
  # coordinates which are guaranteed to extend beyond plot boundaries
  deltax <- abs(lims[2]-lims[1])
  xleft <- lims[1]-deltax
  xright <- lims[2]+deltax
  
  deltay <- abs(lims[4]-lims[3])
  ybottom <- lims[3]-deltay
  ytop <- lims[4]+deltay
  
  if(!missing(pheno)){
    # remove any alpha value from pheno$col
    opaque.rgb <- col2rgb(pheno$col)/255
    opaquecolor <- rgb(red=opaque.rgb[1],green=opaque.rgb[2],blue=opaque.rgb[3])
    
    if(debug){
      cat("Phenomenological value supplied\n")
      print(pheno)
    }
    
    rect( xleft=xleft, xright=xright, ybottom=pheno$val-pheno$dval,
          ytop=pheno$val+pheno$dval, col=pheno$col, border=opaquecolor )    

    if(!missing(solutions)){
      if(debug){
        cat("Solutions supplied\n")
        print(solutions)
      }
      
      # add band indicating solution      
      rect( xleft=solutions$val-solutions$dval, xright=solutions$val+solutions$dval, ybottom=ybottom,
            ytop=pheno$val+pheno$dval, col=rgb(red=0.0,blue=1.0,green=0.0,alpha=0.2), border='blue' )
      # and add point on top
      colours <- 'blue'
      symbols <- 18
      if(!missing(lg)) {
        colours <- lg$col[length(lg$col)]
        symbols <- lg$pch[length(lg$pch)]
      }
      plotwitherror( y=pheno$val, x=solutions$val, dx=solutions$dval, dy=pheno$dval, rep=T, col=colours, pch=symbols )
    }        
  }
  
  # add data points on top of any bands that were drawn
  plotwitherror( y=df$y, x=df$x, dy=df$dy, rep=T )
  
  if(!missing(extrapolations)){
    if(debug){
      cat("Extrapolated points supplied\n")
      print(extrapolations)
    }  
    colours <- 'red'
    symbols <- 16
    if(!missing(lg)) {
        colours <- lg$col[2:length(lg$col)]
        symbols <- lg$pch[2:length(lg$pch)]
    }
    plotwitherror( y=extrapolations$val, dy=extrapolations$dval, 
                   x=extrapolations[extrapolations$plot.idx[1]], dx=extrapolations[extrapolations$plot.idx[2]], 
                   col=colours, pch=symbols, rep=T )
  }
  
  # legend still missing
  if(!missing(lg)){
    legend(x=lims[1],y=lims[4],legend=lg$labels,pch=lg$pch,col=lg$col,bty="n")
  }
  
  dev.off()
  tools::texi2dvi(texfile,pdf=T)
  command <- sprintf("pdfcrop %s %s",pdffile,pdffile)
  system(command)
}

# it is unclear to me whether this kind of function is useful...
# because it would need to be provided with quite a number of arguments
# fes.hadron_obs <- function(name, hadron_obs, ) {
#   pheno <- cbind(phys_ratios[phys_ratios$name==name,],col=pheno.col,pch=pheno.pch)
#   obs <- select.hadron_obs(hadron_obs,by='name',filter=name)
#   
#   pred.idx <- list(m.val=c(2,3),m.sea=vector())
#   dat.fes <- extract.for.fes_fit(hadron_obs=obs,pred.idx=pred.idx)
#   fes.fit <- fes_fit_linear(dat=dat.fes,debug=F)
#   pred <- data.frame(x1=c(mu_s$val,mu_s$val[3]),x2=mu_c$val[1:4],dx1=c(mu_s$dval,mu_s$dval[3]),dx2=mu_c$dval[1:4])
#   fes.extrapolate <- fes_extrapolate(fesfit=fes.fit, pred=pred)
# 
#   extrapolations <- rbind(extrapolations, 
#                           data.frame(name=name,
#                                     val=apply(X=fes.extrapolate$y,MARGIN=2,FUN=mean),
#                                     dval=sqrt( apply(X=fes.extrapolate$y,MARGIN=2,FUN=sd)^2 + apply(X=fes.extrapolate$dy,MARGIN=2,FUN=mean)^2 ),
#                                     x=c(mu_s$val,mu_s$val[3]), dx=c(mu_s$dval,mu_s$dval[3])
#                                     )
#                         )
# 
#   df <- extract.for.plot(hadron_obs=obs,x.name="m.val",x.idx=c(2))
#   plot.hadron_obs(df=df,name=name,pheno=pheno,extrapolations=extrapolations[extrapolations$name==name,],#solutions=solution,
#                   xlab="$a\\mu_s$",ylab=obs[[1]]$texlabel, lg=legend.mu_sc)
# }