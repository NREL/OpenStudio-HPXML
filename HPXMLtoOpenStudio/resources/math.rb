# frozen_string_literal: true

# Collection of methods related to various math tools.
module MathTools
  # Returns the linear interpolation between two results.
  #
  # @param x [Double] the x-coordinate corresponding to the point to interpolate
  # @param x0 [Double] known point 1 x-coordinate
  # @param x1 [Double] known point 2 x-coordinate
  # @param f0 [Double] known point 1 function value
  # @param f1 [Double] known point 2 function value
  # @return [Double] the interpolated value for given x-coordinate
  def self.interp2(x, x0, x1, f0, f1)
    return f0 + ((x - x0) / (x1 - x0)) * (f1 - f0)
  end

  # Returns the bilinear interpolation between four results.
  #
  # @param x [Double] the x-coordinate corresponding to the point to interpolate
  # @param y [Double] the y-coordinate corresponding to the point to interpolate
  # @param x1 [Double] known points 1 and 2 x-coordinate
  # @param x2 [Double] known points 3 and 4 x-coordinate
  # @param y1 [Double] known points 1 and 3 y-coordinate
  # @param y2 [Double] known points 2 and 4 y-coordinate
  # @param fx1y1 [Double] known point 1 function value
  # @param fx1y2 [Double] known point 2 function value
  # @param fx2y1 [Double] known point 3 function value
  # @param fx2y2 [Double] known point 4 function value
  # @return [Double] the interpolated value for the given x- and y- coordinates
  def self.interp4(x, y, x1, x2, y1, y2, fx1y1, fx1y2, fx2y1, fx2y2)
    return (fx1y1 / ((x2 - x1) * (y2 - y1))) * (x2 - x) * (y2 - y) \
          + (fx2y1 / ((x2 - x1) * (y2 - y1))) * (x - x1) * (y2 - y) \
          + (fx1y2 / ((x2 - x1) * (y2 - y1))) * (x2 - x) * (y - y1) \
          + (fx2y2 / ((x2 - x1) * (y2 - y1))) * (x - x1) * (y - y1)
  end

  # Calculate the result of a biquadratic polynomial with independent variables.
  # x and y, and a list of coefficients, c:
  #
  # z = c[1] + c[2]*x + c[3]*x**2 + c[4]*y + c[5]*y**2 + c[6]*x*y
  #
  # @param x [Double] independent variable 1
  # @param y [Double] independent variable 2
  # @param c [Array<Double>] list of 6 coefficients
  # @return [Double] result of biquadratic polynomial
  def self.biquadratic(x, y, c)
    if c.length != 6
      fail 'Error: There must be 6 coefficients in a biquadratic polynomial'
    end

    z = c[0] + c[1] * x + c[2] * x**2 + c[3] * y + c[4] * y**2 + c[5] * y * x
    return z
  end

  # Calculate the result of a quadratic polynomial with independent variable.
  # x and a list of coefficients, c:
  #
  # y = c[1] + c[2]*x + c[3]*x**2
  #
  # @param x [Double] independent variable
  # @param c [Array<Double>] list of 3 coefficients
  # @return [Double] result of quadratic polynomial
  def self.quadratic(x, c)
    if c.size != 3
      fail 'Error: There must be 3 coefficients in a quadratic polynomial'
    end

    y = c[0] + c[1] * x + c[2] * x**2

    return y
  end

  # Calculate the result of a bicubic polynomial with independent variables.
  # x and y, and a list of coefficients, c:

  # z = c[1] + c[2]*x + c[3]*y + c[4]*x**2 + c[5]*x*y + c[6]*y**2 + \
  #     c[7]*x**3 + c[8]*y*x**2 + c[9]*x*y**2 + c[10]*y**3
  #
  # @param x [Double] independent variable 1
  # @param y [Double] independent variable 2
  # @param c [Array<Double>] list of 10 coefficients
  # @return [Double] result of bicubic polynomial
  def self.bicubic(x, y, c)
    if c.size != 10
      fail 'Error: There must be 10 coefficients in a bicubic polynomial'
    end

    z = c[0] + c[1] * x + c[2] * x**2 + c[3] * y + c[4] * y**2 + c[5] * x * y + \
        c[6] * x**3 + c[7] * y**3 + c[8] * x**2 * y + c[9] * x * y**2

    return z
  end

  # Determine if a guess is within tolerance for convergence.
  # If not, output a new guess using the Newton-Raphson method.
  #
  # Based on XITERATE f77 code in ResAC (Brandemuehl).
  #
  # @param x0 [Double] current guess value
  # @param f0 [Double] value of function f(x) at current guess value
  # @param x1 [Double] previous two guess values, used to create quadratic (or linear fit)
  # @param f1 [Double] previous two values of f(x)
  # @param x2 [Double] previous two guess values, used to create quadratic (or linear fit)
  # @param f2 [Double] previous two values of f(x)
  # @param icount [Integer] iteration count
  # @param cvg [Boolean] whether the iteration has reached convergence
  # @return [Double, Boolean, Double, Double, Double, Double] new guess value, whether the iteration has reached convergence, updated previous two guess values, used to create quadratic (or linear fit), updated previous two values of f(x)
  def self.Iterate(x0, f0, x1, f1, x2, f2, icount, cvg)
    '''
    Example:
    --------
        # Find a value of x that makes f(x) equal to some specific value f:
        # initial guess (all values of x)
        x = 1.0
        x1 = x
        x2 = x
        # initial error
        error = f - f(x)
        error1 = error
        error2 = error
        itmax = 50  # maximum iterations
        cvg = False # initialize convergence to "False"
        for i in range(1,itmax+1):
            error = f - f(x)
            x,cvg,x1,error1,x2,error2 = \
                                     Iterate(x,error,x1,error1,x2,error2,i,cvg)
            if cvg:
                break
        if cvg:
            print "x converged after", i, :iterations"
        else:
            print "x did NOT converge after", i, "iterations"
        print "x, when f(x) is", f,"is", x
    '''

    tolRel = 1e-5
    dx = 0.1

    # Test for convergence
    if (((x0 - x1).abs < tolRel * [x0.abs, Constants.small].max) && (icount != 1)) || (f0 == 0)
      x_new = x0
      cvg = true
    else
      cvg = false

      if icount == 1 # Perturbation
        mode = 1
      elsif icount == 2 # Linear fit
        mode = 2
      else # Quadratic fit
        mode = 3
      end

      if mode == 3
        # Quadratic fit
        if x0 == x1 # If two xi are equal, use a linear fit
          x1 = x2
          f1 = f2
          mode = 2
        elsif x0 == x2 # If two xi are equal, use a linear fit
          mode = 2
        else
          # Set up quadratic coefficients
          c = ((f2 - f0) / (x2 - x0) - (f1 - f0) / (x1 - x0)) / (x2 - x1)
          b = (f1 - f0) / (x1 - x0) - (x1 + x0) * c
          a = f0 - (b + c * x0) * x0

          if c.abs < Constants.small # If points are co-linear, use linear fit
            mode = 2
          elsif ((a + (b + c * x1) * x1 - f1) / f1).abs > Constants.small
            # If coefficients do not accurately predict data points due to
            # round-off, use linear fit
            mode = 2
          else
            d = b**2 - 4.0 * a * c # calculate discriminant to check for real roots
            if d < 0.0 # if no real roots, use linear fit
              mode = 2
            else
              if d > 0.0 # if real unequal roots, use nearest root to recent guess
                x_new = (-b + Math.sqrt(d)) / (2 * c)
                x_other = -x_new - b / c
                if (x_new - x0).abs > (x_other - x0).abs
                  x_new = x_other
                end
              else # If real equal roots, use that root
                x_new = -b / (2 * c)
              end

              if (f1 * f0 > 0) && (f2 * f0 > 0) # If the previous two f(x) were the same sign as the new
                if f2.abs > f1.abs
                  x2 = x1
                  f2 = f1
                end
              else
                if f2 * f0 > 0
                  x2 = x1
                  f2 = f1
                end
              end
              x1 = x0
              f1 = f0
            end
          end
        end
      end

      if mode == 2
        # Linear Fit
        m = (f1 - f0) / (x1 - x0)
        if m == 0 # If slope is zero, use perturbation
          mode = 1
        else
          x_new = x0 - f0 / m
          x2 = x1
          f2 = f1
          x1 = x0
          f1 = f0
        end
      end

      if mode == 1
        # Perturbation
        if x0.abs > Constants.small
          x_new = x0 * (1 + dx)
        else
          x_new = dx
        end
        x2 = x1
        f2 = f1
        x1 = x0
        f1 = f0
      end
    end
    return x_new, cvg, x1, f1, x2, f2
  end
end
